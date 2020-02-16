const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  balance,
  BN,
  constants,
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const {
  _0,
  _25,
  _100,
  doDmmEtherBeforeEach,
  mint,
  blacklistUser,
  disableMarkets,
  pauseEcosystem,
} = require('./helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, other, user] = accounts;

describe('DmmEther.ContractInteractions', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doDmmEtherBeforeEach(this, contract, web3, accounts[accounts.length - 1]);
  });

  /********************************
   * MintFrom Function
   */

  it('should mintFrom to owner via admin if wallet is set up', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    const receipt = await this.contract.mintFrom(user, admin, _25(), {from: admin});

    expectEvent(
      receipt,
      'Mint',
      {minter: user, recipient: admin, amount: _25()}
    );

    (await this.contract.balanceOf(admin)).should.be.bignumber.equal(_25());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100().sub(_25()));
  });

  it('should not mintFrom to owner if sender is not approved', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(user, other, _25(), {from: other}),
      'INSUFFICIENT_ALLOWANCE',
    );
  });

  it('should not mintFrom if ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(user, admin, _25(), {from: admin}),
      'ECOSYSTEM_PAUSED'
    )
  });

  it('should not mintFrom if market is disabled', async () => {
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(user, admin, _25(), {from: admin}),
      'MARKET_DISABLED'
    );
  });

  it('should not mintFrom if owner is blacklisted', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, user, admin);

    await expectRevert(
      this.contract.mintFrom(user, admin, _25(), {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not mintFrom if msg.sender is blacklisted', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, admin, admin);

    await expectRevert(
      this.contract.mintFrom(user, admin, _25(), {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not mintFrom if receiver is blacklisted', async () => {
    await blacklistUser(this.blacklistable, other, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(user, other, _25(), {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not mintFrom if amount is too small', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFrom(user, admin, new BN('1'), {from: admin}),
      'INSUFFICIENT_MINT_AMOUNT'
    );
  });

  /********************************
   * Mint from via Ether Function
   */

  it('should mintFromViaEther to owner via admin if wallet is set up', async () => {
    const adminBalance = await balance.current(admin);
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    const gasPrice = new BN(1e9);
    const receipt = await this.contract.mintFromViaEther(user, admin, {from: admin, value: _25(), gasPrice});
    const totalGasCost = gasPrice.mul(new BN(receipt.receipt.gasUsed));

    expectEvent(
      receipt,
      'Mint',
      {minter: user, recipient: admin, amount: _25()}
    );

    (await this.contract.balanceOf(admin)).should.be.bignumber.equal(_25());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100());
    (await balance.current(admin)).should.be.bignumber.equal(adminBalance.sub(totalGasCost).sub(_25()));
  });

  it('should mintFromViaEther to owner if sender is not approved', async () => {
    // This works because msg.sender sends the funds anyway
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    const adminBalance = await balance.current(admin);

    const gasPrice = new BN(1e9);
    const receipt = await this.contract.mintFromViaEther(user, admin, {from: admin, value: _25(), gasPrice});
    const totalGasCost = gasPrice.mul(new BN(receipt.receipt.gasUsed));

    expectEvent(
      receipt,
      'Mint',
      {minter: user, recipient: admin, amount: _25()}
    );

    (await this.contract.balanceOf(admin)).should.be.bignumber.equal(_25());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100());
    (await balance.current(admin)).should.be.bignumber.equal(adminBalance.sub(totalGasCost).sub(_25()));
  });

  it('should not mintFromViaEther if ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFromViaEther(user, admin, {from: admin, value: _25()}),
      'ECOSYSTEM_PAUSED'
    )
  });

  it('should not mintFromViaEther if market is disabled', async () => {
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFromViaEther(user, admin, {from: admin, value: _25()}),
      'MARKET_DISABLED'
    );
  });

  it('should not mintFromViaEther if owner is blacklisted', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, user, admin);

    await expectRevert(
      this.contract.mintFromViaEther(user, admin, {from: admin, value: _25()}),
      'BLACKLISTED'
    );
  });

  it('should not mintFromViaEther if msg.sender is blacklisted', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await blacklistUser(this.blacklistable, admin, admin);

    await expectRevert(
      this.contract.mintFromViaEther(user, admin, {from: admin, value: _25()}),
      'BLACKLISTED'
    );
  });

  it('should not mintFromViaEther if receiver is blacklisted', async () => {
    await blacklistUser(this.blacklistable, other, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFromViaEther(user, other, {from: admin, value: _25()}),
      'BLACKLISTED'
    );
  });

  it('should not mintFromViaEther if amount is too small', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintFromViaEther(user, admin, {from: admin, value: new BN('1')}),
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

    const adminBalance = await balance.current(admin);

    const gasPrice = new BN(1e9);
    const receipt = await this.contract.redeemFrom(user, admin, _25(), {from: admin, gasPrice});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: admin, amount: _25()}
    );
    const totalGasUsed = gasPrice.mul(new BN(receipt.receipt.gasUsed));

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.contract.balanceOf(admin)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100().sub(_25()));
    (await this.underlyingToken.balanceOf(admin)).should.be.bignumber.equal(_0());
    (await balance.current(admin)).should.be.bignumber.equal(adminBalance.add(_25()).sub(totalGasUsed));
  });

  it('should redeemFrom if market is disabled', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    const adminBalance = await balance.current(admin);

    const gasPrice = new BN(1e9);
    const receipt = await this.contract.redeemFrom(user, admin, _25(), {from: admin, gasPrice});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: admin, amount: _25()}
    );
    const totalGasUsed = gasPrice.mul(new BN(receipt.receipt.gasUsed));

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.contract.balanceOf(admin)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100().sub(_25()));
    (await this.underlyingToken.balanceOf(admin)).should.be.bignumber.equal(_0());
    (await balance.current(admin)).should.be.bignumber.equal(adminBalance.add(_25()).sub(totalGasUsed));
  });

  it('should not redeemFrom if sender is not approved', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.redeemFrom(user, other, _25(), {from: other}),
      'INSUFFICIENT_ALLOWANCE'
    )
  });

  it('should not redeemFrom if ecosystem is paused', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await pauseEcosystem(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.redeemFrom(user, admin, _25(), {from: admin}),
      'ECOSYSTEM_PAUSED'
    )
  });

  it('should not redeemFrom if sender is not approved', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.redeemFrom(user, other, _25(), {from: other}),
      'INSUFFICIENT_ALLOWANCE'
    );
  });

  it('should not redeemFrom if user is blacklisted', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, user, admin);

    await expectRevert(
      this.contract.redeemFrom(user, admin, _25(), {from: admin}),
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
      this.contract.redeemFrom(user, admin, _25(), {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not redeemFrom if receiver is blacklisted', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, other, admin);

    await expectRevert(
      this.contract.redeemFrom(user, other, _25(), {from: admin}),
      'BLACKLISTED'
    );
  });

  it('should not redeemFrom if amount is too small', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(admin, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.redeemFrom(user, admin, new BN('1'), {from: admin}),
      'INSUFFICIENT_REDEEM_AMOUNT'
    );
  });

});
