const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {BN, constants, expectRevert, expectEvent, time, balance} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1, _10, _100, _10000} = require('../../helpers/DmmTokenTestHelpers');
const {doYieldFarmingExternalProxyBeforeEach, startFarmSeason, endFarmSeason} = require('../../helpers/YieldFarmingHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, owner, user, spender, receiver] = accounts;

describe('DMGYieldFarmingRouter', () => {
  const timeBuffer = new BN('2');
  const tokenUnsupportedError = 'DMGYieldFarmingFundingProxy::_verifyTokensAreSupported: TOKEN_UNSUPPORTED';
  let snapshotId;
  before(async () => {
    this.admin = admin;
    this.guardian = guardian;
    this.owner = owner;
    this.user = user;

    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);

    await doYieldFarmingExternalProxyBeforeEach(this, contract, web3, provider);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    snapshotId = await resetChain(provider, snapshotId);
  });

  const setBalanceAndAllowances = async (balanceBN) => {
    await this.underlyingTokenA.setBalance(user, balanceBN || _100(), {from: user});
    await this.underlyingTokenA_2.setBalance(user, balanceBN || _100(), {from: user});

    await this.underlyingTokenA.approve(this.contract.address, constants.MAX_UINT256, {from: user});
    await this.underlyingTokenA_2.approve(this.contract.address, constants.MAX_UINT256, {from: user});

    await this.yieldFarming.approve(this.contract.address, true, {from: user});
  }

  it('addLiquidity: should add liquidity for an active season', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const result = await this.contract.addLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user}
    );
    (result.receipt.status).should.eq(true);
  });

  it('addLiquidity: should fail when deadline is expired', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const resultPromise = this.contract.addLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      _1(),
      (await time.latest()).sub(timeBuffer),
      {from: user}
    );
    await expectRevert(resultPromise, 'DMGYieldFarmingFundingProxy: EXPIRED');
  });

  it('addLiquidity: should fail when the passed tokens are invalid', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const resultPromise = this.contract.addLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenB_2.address,
      _1(),
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user}
    );
    await expectRevert(resultPromise, tokenUnsupportedError);
  });

  it('addLiquidityETH: should add liquidity for an active season', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const result = await this.contract.addLiquidityETH(
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user, value: _1()},
    );
    (result.receipt.status).should.eq(true);
  });

  it('addLiquidityETH: should fail when deadline is expired', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const resultPromise = this.contract.addLiquidityETH(
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      (await time.latest()).sub(timeBuffer),
      {from: user, value: _1()},
    );
    await expectRevert(resultPromise, 'DMGYieldFarmingFundingProxy: EXPIRED');
  });

  it('addLiquidityETH: should fail when the passed tokens are invalid', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const resultPromise = this.contract.addLiquidityETH(
      this.underlyingTokenB_2.address,
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user, value: _1()},
    );
    await expectRevert(resultPromise, tokenUnsupportedError);
  });

  it('removeLiquidity: should remove liquidity for an active season', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const originalBalance = await this.tokenA.balanceOf(user);

    let result = await this.contract.addLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user},
    );
    (result.receipt.status).should.eq(true);

    await time.increase(timeBuffer);

    const userLiquidity = await this.yieldFarming.balanceOf(user, this.tokenA.address);

    result = await this.contract.removeLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      userLiquidity,
      new BN('0'),
      new BN('0'),
      (await time.latest()).add(timeBuffer),
      true,
      {from: user},
    );
    (result.receipt.status).should.eq(true);

    (await this.tokenA.balanceOf(user)).should.be.bignumber.eq(originalBalance);
    (await this.dmgToken.balanceOf(user)).should.be.bignumber.gt(new BN('0'));
  });

  it('removeLiquidity: should remove liquidity when there is no active season', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const originalBalance = await this.tokenA.balanceOf(user);

    let result = await this.contract.addLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user},
    );
    (result.receipt.status).should.eq(true);

    await time.increase(timeBuffer);

    await endFarmSeason(this);

    const userLiquidity = await this.yieldFarming.balanceOf(user, this.tokenA.address);
    result = await this.contract.removeLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      userLiquidity,
      new BN('0'),
      new BN('0'),
      (await time.latest()).add(timeBuffer),
      false,
      {from: user},
    );
    (result.receipt.status).should.eq(true);

    (await this.tokenA.balanceOf(user)).should.be.bignumber.eq(originalBalance);
    (await this.dmgToken.balanceOf(user)).should.be.bignumber.eq(new BN('0'));
  });

  it('removeLiquidity: should fail when deadline is expired', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const result = await this.contract.addLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user},
    );
    (result.receipt.status).should.eq(true);

    await time.increase(timeBuffer);

    const userLiquidity = await this.yieldFarming.balanceOf(user, this.tokenA.address);
    const resultPromise = this.contract.removeLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      userLiquidity,
      new BN('0'),
      new BN('0'),
      (await time.latest()).sub(timeBuffer),
      true,
      {from: user},
    );
    await expectRevert(resultPromise, 'DMGYieldFarmingFundingProxy: EXPIRED');
  });

  it('removeLiquidity: should fail when the passed tokens are invalid', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const result = await this.contract.addLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user},
    );
    (result.receipt.status).should.eq(true);

    await time.increase(timeBuffer);

    const userLiquidity = await this.yieldFarming.balanceOf(user, this.tokenA.address);
    const resultPromise = this.contract.removeLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenB_2.address,
      userLiquidity,
      new BN('0'),
      new BN('0'),
      (await time.latest()).add(timeBuffer),
      true,
      {from: user},
    );
    await expectRevert(resultPromise, tokenUnsupportedError);
  });

  it('removeLiquidityETH: should remove liquidity for an active season', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const originalBalanceA = await this.tokenA.balanceOf(user);
    const originalBalanceUnderlyingA = await this.underlyingTokenA.balanceOf(user);
    const originalBalanceUnderlyingA_2 = await this.underlyingTokenA_2.balanceOf(user);
    const gasPrice = new BN('1000000000');
    const gasFees = new BN('1000000').mul(gasPrice);
    const originalEthBalance = await balance.current(user);

    let result = await this.contract.addLiquidityETH(
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user, value: _1(), gasPrice},
    );
    (result.receipt.status).should.eq(true);

    await time.increase(timeBuffer);

    const userLiquidity = await this.yieldFarming.balanceOf(user, this.tokenA.address);

    result = await this.contract.removeLiquidityETH(
      this.underlyingTokenA_2.address,
      userLiquidity,
      new BN('0'),
      new BN('0'),
      (await time.latest()).add(timeBuffer),
      true,
      {from: user, gasPrice},
    );
    (result.receipt.status).should.eq(true);

    const uniswapFees = new BN('1000');
    (await this.tokenA.balanceOf(user)).should.be.bignumber.eq(originalBalanceA);
    (await this.underlyingTokenA.balanceOf(user)).should.be.bignumber.gte(originalBalanceUnderlyingA.sub(uniswapFees));
    (await this.underlyingTokenA_2.balanceOf(user)).should.be.bignumber.gte(originalBalanceUnderlyingA_2.sub(uniswapFees));
    (await balance.current(user)).should.be.bignumber.gt(originalEthBalance.sub(gasFees));
    (await this.dmgToken.balanceOf(user)).should.be.bignumber.gt(new BN('0'));
  });

  it('removeLiquidityETH: should remove liquidity when there is no season', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    let result = await this.contract.addLiquidityETH(
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user, value: _1()},
    );
    (result.receipt.status).should.eq(true);

    await time.increase(timeBuffer);

    await endFarmSeason(this);

    const userLiquidity = await this.yieldFarming.balanceOf(user, this.tokenA.address);

    result = await this.contract.removeLiquidityETH(
      this.underlyingTokenA_2.address,
      userLiquidity,
      new BN('0'),
      new BN('0'),
      (await time.latest()).add(timeBuffer),
      false,
      {from: user},
    );
    (result.receipt.status).should.eq(true);
  });

  it('removeLiquidityETH: should fail when deadline is expired', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const result = await this.contract.addLiquidityETH(
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user, value: _1()},
    );
    (result.receipt.status).should.eq(true);

    await time.increase(timeBuffer);

    const userLiquidity = await this.yieldFarming.balanceOf(user, this.tokenA.address);
    const resultPromise = this.contract.removeLiquidityETH(
      this.underlyingTokenA_2.address,
      userLiquidity,
      new BN('0'),
      new BN('0'),
      (await time.latest()).sub(timeBuffer),
      true,
      {from: user},
    );
    await expectRevert(resultPromise, 'DMGYieldFarmingFundingProxy: EXPIRED');
  });

  it('removeLiquidityETH: should fail when the passed tokens are invalid', async () => {
    await startFarmSeason(this);
    await setBalanceAndAllowances();

    const result = await this.contract.addLiquidityETH(
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      (await time.latest()).add(timeBuffer),
      {from: user, value: _1()},
    );
    (result.receipt.status).should.eq(true);

    await time.increase(timeBuffer);

    const userLiquidity = await this.yieldFarming.balanceOf(user, this.tokenA.address);
    const resultPromise = this.contract.removeLiquidityETH(
      this.underlyingTokenB_2.address,
      userLiquidity,
      new BN('0'),
      new BN('0'),
      (await time.latest()).add(timeBuffer),
      true,
      {from: user},
    );
    await expectRevert(resultPromise, tokenUnsupportedError);
  });

});