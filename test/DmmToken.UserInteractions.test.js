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
  doDmmTokenBeforeEach,
  mint,
  blacklistUser,
  disableMarkets,
  pauseEcosystem,
} = require('./helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, deployer, user] = accounts;

describe('DmmToken.UserInteractions', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doDmmTokenBeforeEach(this, contract, web3);
  });

  /********************************
   * Mint Function
   */

  it('should mint to owner if wallet is set up', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    const receipt = await this.contract.mint(_25(), {from: user});

    expectEvent(
      receipt,
      'Mint',
      {minter: user, recipient: user, amount: _25()}
    );

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_25());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_10000().sub(_25()));
  });

  it('should not mint if ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mint(_25(), {from: user}),
      'ECOSYSTEM_PAUSED'
    );
  });

  it('should not mint if market is disabled', async () => {
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mint(_25(), {from: user}),
      'MARKET_DISABLED'
    );
  });

  it('should not mint if user is blacklisted', async () => {
    await blacklistUser(this.blacklistable, user, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mint(_25(), {from: user}),
      'BLACKLISTED'
    );
  });

  it('should not mint if amount is too small', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mint(new BN('1'), {from: user}),
      'INSUFFICIENT_MINT_AMOUNT'
    );
  });

  /********************************
   * Redeem Functions
   */

  it('should redeem to sender via admin if wallet is set up', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    const receipt = await this.contract.redeem(_25(), {from: user});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: user, amount: _25()}
    );

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_10000());
  });

  it('should redeem if market is disabled', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    const receipt = await this.contract.redeem(_25(), {from: user});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: user, amount: _25()}
    );

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_10000());
  });

  it('should not redeem if ecosystem is paused', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await pauseEcosystem(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.redeem(_25(), {from: user}),
      'ECOSYSTEM_PAUSED'
    )
  });

  it('should not redeem if sender is blacklisted', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, user, admin);

    await expectRevert(
      this.contract.redeem(_25(), {from: user}),
      'BLACKLISTED'
    );
  });

});
