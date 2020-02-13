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
  _10000,
  _1000000,
  doDmmEtherBeforeEach,
  mint,
  blacklistUser,
  disableMarkets,
  pauseEcosystem,
} = require('./helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, deployer, user] = accounts;

describe('DmmEther.UserInteractions', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doDmmEtherBeforeEach(this, contract, web3, accounts[accounts.length - 1]);
  });

  /********************************
   * Mint via ETH Functions
   */

  it('should mint via ETH to sender if wallet is set up', async () => {
    const gasLimit = new BN('250000');
    const gasPrice = new BN('1000000000');
    const result1 = await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user, gasPrice});
    const result2 = await this.contract.mintViaEther({value: _25(), from: user, gas: gasLimit, gasPrice});

    expectEvent(
      result2,
      'Mint',
      {minter: user, recipient: user, amount: _25()}
    );
    const totalGasUsed = (new BN(result1.receipt.gasUsed).add(new BN(result2.receipt.gasUsed))).mul(gasPrice);

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_25());
    (await balance.current(user)).should.be.bignumber.equal(_1000000().sub(_25()).sub(totalGasUsed));
  });

  it('should not mint via ETH if ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintViaEther({value: _25(), from: user}),
      'ECOSYSTEM_PAUSED'
    );
  });

  it('should not mint via ETH if market is disabled', async () => {
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintViaEther({value: _25(), from: user}),
      'MARKET_DISABLED'
    );
  });

  it('should not mint via ETH if user is blacklisted', async () => {
    await blacklistUser(this.blacklistable, user, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintViaEther({value: _25(), from: user}),
      'BLACKLISTED'
    );
  });

  it('should not mint via ETH if amount is too small', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.mintViaEther({value: new BN('1'), from: user}),
      'INSUFFICIENT_MINT_AMOUNT'
    );
  });

  /********************************
   * Mint via WETH Functions
   */

  it('should mint to sender if wallet is set up', async () => {
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    const receipt = await this.contract.mint(_25(), {from: user});

    expectEvent(
      receipt,
      'Mint',
      {minter: user, recipient: user, amount: _25()}
    );
    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_25());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100().sub(_25()));
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
   * Redeem to ETH Functions
   */

  it('should redeem if wallet is set up', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    const originalBalance = await balance.current(user);
    const gasPrice = new BN(1e9);
    const receipt = await this.contract.redeem(_25(), {from: user, gasPrice});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: user, amount: _25()}
    );
    const gasCost = new BN(receipt.receipt.gasUsed).mul(gasPrice);

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100().sub(_25()));
    // We redeem to ETH, so the user should have more ETH
    (await balance.current(user)).should.be.bignumber.equal(originalBalance.add(_25()).sub(gasCost));
  });

  it('should redeem if market is disabled', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    const originalBalance = await balance.current(user);
    const gasPrice = new BN(1e9);
    const receipt = await this.contract.redeem(_25(), {from: user, gasPrice});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: user, amount: _25()}
    );
    const gasCost = new BN(receipt.receipt.gasUsed).mul(gasPrice);

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100().sub(_25()));
    // We redeem to ETH, so the user should have more ETH
    (await balance.current(user)).should.be.bignumber.equal(originalBalance.add(_25()).sub(gasCost));
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

  /********************************
   * Redeem to WETH Functions
   */

  it('should redeem and output WETH if wallet is set up', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    const receipt = await this.contract.redeemToWETH(_25(), {from: user});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: user, amount: _25()}
    );

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100());
  });

  it('should redeem and output to WETH if market is disabled', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await disableMarkets(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    const receipt = await this.contract.redeemToWETH(_25(), {from: user});
    expectEvent(
      receipt,
      'Redeem',
      {redeemer: user, recipient: user, amount: _25()}
    );

    (await this.contract.balanceOf(user)).should.be.bignumber.equal(_0());
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.equal(_100());
  });

  it('should not redeem to WETH if ecosystem is paused', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await pauseEcosystem(this.controller, admin);
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await expectRevert(
      this.contract.redeemToWETH(_25(), {from: user}),
      'ECOSYSTEM_PAUSED'
    )
  });

  it('should not redeem to WETH if sender is blacklisted', async () => {
    await mint(this.underlyingToken, this.contract, user, _25());
    await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await blacklistUser(this.blacklistable, user, admin);

    await expectRevert(
      this.contract.redeemToWETH(_25(), {from: user}),
      'BLACKLISTED'
    );
  });

});
