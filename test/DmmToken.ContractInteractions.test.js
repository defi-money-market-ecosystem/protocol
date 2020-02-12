const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  BN,
  constants,
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const {
  _0,
  _25,
  _10000,
  doBeforeEach,
  mint,
  blacklistUser,
  disableMarkets,
  pauseEcosystem,
} = require('./helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, deployer, user] = accounts;

describe('DmmToken.ContractInteractions', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doBeforeEach(this, contract, web3);
  });

  /********************************
   * MintFrom Function
   */

  it('should mintFrom to sender via admin if wallet is set up', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.underlyingToken.approve(admin, constants.MAX_UINT256, {from: user});
    const receipt = await this.contract.mintFrom(_25(), user, admin, {from: admin});

    expectEvent(
      receipt,
      'Mint',
      {minter: user, recipient: admin, amount: _25()}
    );

    (await this.contract.balanceOf(admin)).should.be.bignumber.equal(_25());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_10000().sub(_25()));
  });

  it('should not mintFrom if ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.underlyingToken.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(_25(), user, admin, {from: admin}),
      'ECOSYSTEM_PAUSED'
    )
  });

  it('should not mintFrom if market is disabled', async () => {
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.underlyingToken.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(_25(), user, admin, {from: admin}),
      'MARKET_DISABLED'
    );
  });

  it('should not mintFrom if sender is blacklisted', async () => {
    await blacklistUser(this.blacklistable, user, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.underlyingToken.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(_25(), user, admin, {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not mintFrom if msg.sender is blacklisted', async () => {
    await blacklistUser(this.blacklistable, admin, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.underlyingToken.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(_25(), user, admin, {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not mintFrom if receiver is blacklisted', async () => {
    await blacklistUser(this.blacklistable, deployer, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.underlyingToken.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(_25(), user, deployer, {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not mintFrom if amount is too small', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.underlyingToken.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(new BN('1'), user, admin, {from: admin}),
      'INSUFFICIENT_MINT_AMOUNT'
    );
  });

  /********************************
   * Redeem From Functions
   */

  it('should redeemFrom to sender via admin if wallet is set up', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    const receipt = await this.contract.redeemFrom(_25(), user, admin, {from: admin});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: admin, amount: _25()}
    );

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.contract.balanceOf(admin)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_10000().sub(_25()));
    (await this.underlyingToken.balanceOf(admin)).should.be.bignumber.equal(_25());
  });

  it('should not redeemFrom if ecosystem is paused', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await pauseEcosystem(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.redeemFrom(_25(), user, admin, {from: admin}),
      'ECOSYSTEM_PAUSED'
    )
  });

  it('should redeemFrom if market is disabled', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    const receipt = await this.contract.redeemFrom(_25(), user, admin, {from: admin});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: admin, amount: _25()}
    );

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.contract.balanceOf(admin)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_10000().sub(_25()));
    (await this.underlyingToken.balanceOf(admin)).should.be.bignumber.equal(_25());
  });

  it('should not redeemFrom if sender is blacklisted', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, user, admin);

    await expectRevert(
      this.contract.redeemFrom(_25(), user, admin, {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not redeemFrom if msg.sender is blacklisted', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, admin, admin);

    await expectRevert(
      this.contract.redeemFrom(_25(), user, admin, {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not redeemFrom if receiver is blacklisted', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, deployer, admin);

    await expectRevert(
      this.contract.redeemFrom(_25(), user, deployer, {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not redeemFrom if amount is too small', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.redeemFrom(new BN('1'), user, admin, {from: admin}),
      'INSUFFICIENT_REDEEM_AMOUNT'
    );
  });

});
