const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {BN, constants, expectRevert, expectEvent, time} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1, _10, _100, _10000} = require('../../helpers/DmmTokenTestHelpers');
const {doYieldFarmingBeforeEach, startFarmSeason, endFarmSeason} = require('../../helpers/YieldFarmingHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, owner, user, spender, receiver, proxy] = accounts;

describe('DMGYieldFarmingV1.User', () => {
  const timeBuffer = new BN('2');
  const points2 = new BN('3');
  const pointsFactor = new BN('2');
  let snapshotId;
  let dmgGrowthCoefficient;
  before(async () => {
    this.admin = admin;
    this.guardian = guardian;
    this.owner = owner;
    this.user = user;

    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);

    await doYieldFarmingBeforeEach(this, contract, web3);

    dmgGrowthCoefficient = await this.yieldFarming.dmgGrowthCoefficient();

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    snapshotId = await resetChain(provider, snapshotId);
  });

  it('approve: should set spender to be approved and unapproved', async () => {
    let result = await this.yieldFarming.approve(spender, true, {from: user});
    expectEvent(result, 'Approval', {user, spender, isTrusted: true});
    (await this.yieldFarming.isApproved(user, spender)).should.eq(true);

    result = await this.yieldFarming.approve(spender, false, {from: user});
    expectEvent(result, 'Approval', {user, spender, isTrusted: false});
    (await this.yieldFarming.isApproved(user, spender)).should.eq(false);
  });

  it('beginFarming: should farm properly for 1 token with 1 deposit', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);
    const lastIndexTimestamp = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    const latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference = latestTimestamp.sub(lastIndexTimestamp);

    (timeDifference).should.be.bignumber.gte(_100Seconds);
    (timeDifference).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const expectedRewardAmount = deposit1.mul(new BN('101')).div(new BN('100')).mul(timeDifference).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);
  });

  it('beginFarming: should farm properly for 1 token with 1 deposit from global proxy', async () => {
    await this.yieldFarming.approveGloballyTrustedProxy(proxy, true, {from: owner})

    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: proxy});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);
    const lastIndexTimestamp = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    const latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference = latestTimestamp.sub(lastIndexTimestamp);

    (timeDifference).should.be.bignumber.gte(_100Seconds);
    (timeDifference).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const expectedRewardAmount = deposit1.mul(new BN('101')).div(new BN('100')).mul(timeDifference).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);
  });

  it('beginFarming: should farm properly for 1 token with 1 deposit, then should redeposit 0 for next season', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);
    let lastIndexTimestamp = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    let latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    let timeDifference = latestTimestamp.sub(lastIndexTimestamp);

    (timeDifference).should.be.bignumber.gte(_100Seconds);
    (timeDifference).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    let expectedRewardAmount = deposit1.mul(new BN('101')).div(new BN('100')).mul(timeDifference).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);

    await endFarmSeason(this);

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(new BN('0'));

    await startFarmSeason(this, new BN('3'));

    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(new BN('0'));

    result = await this.yieldFarming.beginFarming(user, user, token.address, new BN('0'), {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: new BN('0')},
    );

    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(new BN('0'));

    await time.increase(_100Seconds);
    lastIndexTimestamp = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    timeDifference = latestTimestamp.sub(lastIndexTimestamp);

    (timeDifference).should.be.bignumber.gte(_100Seconds);
    (timeDifference).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    expectedRewardAmount = deposit1.mul(new BN('101')).div(new BN('100')).mul(timeDifference).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);
  });

  it('beginFarming: should farm properly for 1 token with 1 deposit, then should redeposit non-zero amount for next season', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    const deposit2 = _10();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);
    let lastIndexTimestamp = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    let latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    let timeDifference = latestTimestamp.sub(lastIndexTimestamp);

    (timeDifference).should.be.bignumber.gte(_100Seconds);
    (timeDifference).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    let expectedRewardAmount = deposit1.mul(new BN('101')).div(new BN('100')).mul(timeDifference).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);

    await endFarmSeason(this);

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(new BN('0'));

    await startFarmSeason(this, new BN('3'));

    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(new BN('0'));

    result = await this.yieldFarming.beginFarming(user, user, token.address, deposit2, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit2},
    );

    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(new BN('0'));

    await time.increase(_100Seconds);
    lastIndexTimestamp = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    timeDifference = latestTimestamp.sub(lastIndexTimestamp);

    (timeDifference).should.be.bignumber.gte(_100Seconds);
    (timeDifference).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    expectedRewardAmount = (deposit1.add(deposit2)).mul(new BN('101')).div(new BN('100')).mul(timeDifference).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);
  });

  it('beginFarming: should farm properly for 1 token with 1 deposit from another spender that is trusted', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    let result = await this.yieldFarming.approve(spender, true, {from: user});
    expectEvent(result, 'Approval', {user, spender, isTrusted: true});
    (await this.yieldFarming.isApproved(user, spender)).should.eq(true);

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: spender});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);
    const lastIndexTimestamp = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    const latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference = latestTimestamp.sub(lastIndexTimestamp);

    (timeDifference).should.be.bignumber.gte(_100Seconds);
    (timeDifference).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const expectedRewardAmount = deposit1.mul(new BN('101')).div(new BN('100')).mul(timeDifference).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);
  });

  it('beginFarming: should farm properly for 1 token with strange decimals and 1 deposit', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenB;

    const balance = new BN('10000000000')
    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, balance);
    const deposit1 = new BN('100000000');
    const result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(balance.sub(deposit1));

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);
    const lastIndexTimestamp = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    const latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference = latestTimestamp.sub(lastIndexTimestamp);

    (timeDifference).should.be.bignumber.gte(_100Seconds);
    (timeDifference).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const factor = new BN('10').pow(new BN('12')); // 18 - 6 == 12
    const expectedRewardAmount = deposit1.mul(factor).mul(new BN('99')).div(new BN('100')).mul(timeDifference).mul(dmgGrowthCoefficient).div(_1()).mul(points2).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);
  });

  it('beginFarming: should farm properly for 1 token with multiple deposits', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    const balance = _10000();
    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, balance);
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(balance.sub(deposit1));

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);
    const lastIndexTimestamp1 = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    let latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference1 = latestTimestamp.sub(lastIndexTimestamp1);

    (timeDifference1).should.be.bignumber.gte(_100Seconds);
    (timeDifference1).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    let expectedRewardAmount = deposit1.mul(new BN('101')).div(new BN('100')).mul(timeDifference1).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);

    // Deposit #2

    const deposit2 = _10();
    result = await this.yieldFarming.beginFarming(user, user, token.address, deposit2, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit2},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(balance.sub(deposit1).sub(deposit2));

    const _150Seconds = new BN('150');
    await time.increase(_150Seconds);
    const lastIndexTimestamp2 = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference2 = latestTimestamp.sub(lastIndexTimestamp2);

    (timeDifference2).should.be.bignumber.gte(_150Seconds);
    (timeDifference2).should.be.bignumber.lte(_150Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1.add(deposit2));

    // The previous deposit, `deposit1`, still accrues for this duration. We need to account for that before adding the value of deposit 2.
    const timeDifference1_1 = latestTimestamp.sub(lastIndexTimestamp1);
    expectedRewardAmount = (expectedRewardAmount).add(expectedRewardAmount.mul(timeDifference1_1.sub(timeDifference1)).div(timeDifference1));

    const deposit2ValueAccrued = deposit2.mul(new BN('101')).div(new BN('100')).mul(timeDifference2).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    expectedRewardAmount = (expectedRewardAmount).add(deposit2ValueAccrued);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);
  });

  it('beginFarming: should farm properly for 1 token with strange decimals and multiple deposits', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenB;

    const balance = new BN('10000000000');
    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, balance);
    const deposit1 = new BN('100000000');
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(balance.sub(deposit1));

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);
    const lastIndexTimestamp1 = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    let latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference1 = latestTimestamp.sub(lastIndexTimestamp1);

    (timeDifference1).should.be.bignumber.gte(_100Seconds);
    (timeDifference1).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);
    const tokenFactor = new BN('10').pow(new BN('12'));

    let expectedRewardAmount = deposit1.mul(tokenFactor).mul(new BN('99')).div(new BN('100')).mul(timeDifference1).mul(dmgGrowthCoefficient).div(_1()).mul(points2).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);

    // Deposit #2

    const deposit2 = new BN('10000000');
    result = await this.yieldFarming.beginFarming(user, user, token.address, deposit2, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit2},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(balance.sub(deposit1).sub(deposit2));

    const _150Seconds = new BN('150');
    await time.increase(_150Seconds);
    const lastIndexTimestamp2 = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token.address);
    latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference2 = latestTimestamp.sub(lastIndexTimestamp2);

    (timeDifference2).should.be.bignumber.gte(_150Seconds);
    (timeDifference2).should.be.bignumber.lte(_150Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1.add(deposit2));

    // The previous deposit, `deposit1`, still accrues for this duration. We need to account for that before adding the value of deposit 2.
    const timeDifference1_1 = latestTimestamp.sub(lastIndexTimestamp1);
    expectedRewardAmount = expectedRewardAmount.add(expectedRewardAmount.mul(timeDifference1_1.sub(timeDifference1)).div(timeDifference1));

    const deposit2ValueAccrued = deposit2.mul(tokenFactor).mul(new BN('99')).div(new BN('100')).mul(timeDifference2).mul(dmgGrowthCoefficient).div(_1()).mul(points2).mul(pointsFactor);
    expectedRewardAmount = (expectedRewardAmount).add(deposit2ValueAccrued);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount);
  });

  it('beginFarming: should farm properly for 2 tokens with deposits', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token1 = this.tokenA;
    const token2 = this.tokenB;

    const balance1 = _10000();
    await token1.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token1.setBalance(user, balance1);

    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token1.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token1.address, depositedAmount: deposit1},
    );
    (await token1.balanceOf(user)).should.be.bignumber.eq(balance1.sub(deposit1));

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);
    const lastIndexTimestamp1 = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token1.address);
    let latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference1 = latestTimestamp.sub(lastIndexTimestamp1);

    (timeDifference1).should.be.bignumber.gte(_100Seconds);
    (timeDifference1).should.be.bignumber.lte(_100Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token1.address)).should.be.bignumber.eq(deposit1);

    let expectedRewardAmount1 = deposit1.mul(new BN('101')).div(new BN('100')).mul(timeDifference1).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount1);

    // Has 6 decimals
    const balanceToken2 = new BN('10000000000');
    await token2.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token2.setBalance(user, balanceToken2);

    const deposit2 = new BN('125000000');
    result = await this.yieldFarming.beginFarming(user, user, token2.address, deposit2, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token2.address, depositedAmount: deposit2},
    );
    (await token2.balanceOf(user)).should.be.bignumber.eq(balanceToken2.sub(deposit2));

    const _200Seconds = new BN('200');
    await time.increase(_200Seconds);
    const lastIndexTimestamp2 = await this.yieldFarming.getMostRecentDepositTimestampByOwnerAndToken(user, token2.address);
    latestTimestamp = await this.yieldFarming.getMostRecentBlockTimestamp();
    const timeDifference2 = latestTimestamp.sub(lastIndexTimestamp2);

    (timeDifference2).should.be.bignumber.gte(_200Seconds);
    (timeDifference2).should.be.bignumber.lte(_200Seconds.add(timeBuffer));

    (await this.yieldFarming.balanceOf(user, token2.address)).should.be.bignumber.eq(deposit2);

    const timeDifference1_1 = latestTimestamp.sub(lastIndexTimestamp1);
    expectedRewardAmount1 = deposit1.mul(new BN('101')).div(new BN('100')).mul(timeDifference1_1).mul(dmgGrowthCoefficient).div(_1()).mul(pointsFactor);

    (await this.yieldFarming.getRewardBalanceByOwnerAndToken(user, token1.address)).should.be.bignumber.eq(expectedRewardAmount1);

    const factor = new BN('10').pow(new BN('12')); // 18 - 6 == 12
    const expectedRewardAmount2 = deposit2.mul(factor).mul(new BN('99')).div(new BN('100')).mul(timeDifference2).mul(dmgGrowthCoefficient).div(_1()).mul(points2).mul(pointsFactor);
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(expectedRewardAmount1.add(expectedRewardAmount2));
  });

  it('beginFarming: should fail when no season is active', async () => {
    const token = this.tokenA;
    const deposit1 = _100();
    await expectRevert(
      this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user}),
      'DMGYieldFarming: FARM_NOT_ACTIVE',
    );
  });

  it('beginFarming: should fail adding an unsupported token', async () => {
    await startFarmSeason(this);

    const token = this.tokenC;
    const deposit1 = _100();
    await expectRevert(
      this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user}),
      'DMGYieldFarming: TOKEN_UNSUPPORTED',
    );
  });

  it('beginFarming: should fail when the spender is not trusted', async () => {
    await startFarmSeason(this);

    const token = this.tokenA;
    const deposit1 = _100();
    await expectRevert(
      this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: spender}),
      'DMGYieldFarmingV1: UNAPPROVED',
    );
  });

  it('endFarmingByToken: should redeem for 1 token with 1 deposit', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    result = await this.yieldFarming.endFarmingByToken(user, receiver, token.address, {from: user});
    expectEvent(
      result,
      'EndFarming',
      {owner: user, token: token.address, withdrawnAmount: deposit1},
    );
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(new BN('0'));
    (await this.yieldFarming.getRewardBalanceByOwnerAndToken(user, token.address)).should.be.bignumber.eq(new BN('0'));
    (await token.balanceOf(receiver)).should.be.bignumber.eq(deposit1);
  });

  it('endFarmingByToken: should redeem for 1 token with 1 deposit using a trusted spender', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await this.yieldFarming.approve(spender, true, {from: user});

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: spender});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    result = await this.yieldFarming.endFarmingByToken(user, user, token.address, {from: spender});
    expectEvent(
      result,
      'EndFarming',
      {owner: user, token: token.address, withdrawnAmount: deposit1},
    );
    (await this.yieldFarming.getRewardBalanceByOwner(user)).should.be.bignumber.eq(new BN('0'));
    (await this.yieldFarming.getRewardBalanceByOwnerAndToken(user, token.address)).should.be.bignumber.eq(new BN('0'));
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000());
    (await token.balanceOf(spender)).should.be.bignumber.eq(new BN('0'));
  });

  it('endFarmingByToken: should not redeem when a season is not active', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    await endFarmSeason(this);

    await expectRevert(
      this.yieldFarming.endFarmingByToken(user, receiver, token.address, {from: user}),
      'DMGYieldFarming: FARM_NOT_ACTIVE',
    );
  });

  it('endFarmingByToken: should not redeem when the token is not supported', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    await expectRevert(
      this.yieldFarming.endFarmingByToken(user, receiver, this.tokenC.address, {from: user}),
      'DMGYieldFarming: TOKEN_UNSUPPORTED',
    );
  });

  it('withdrawAllWhenOutOfSeason: should withdraw when there is no season', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    await endFarmSeason(this);

    result = await this.yieldFarming.withdrawAllWhenOutOfSeason(user, receiver, {from: user});
    expectEvent(
      result,
      'WithdrawOutOfSeason',
      {owner: user, token: token.address, recipient: receiver, amount: deposit1},
    );
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(new BN('0'));
    (await token.balanceOf(receiver)).should.be.bignumber.eq(deposit1);
  });

  it('withdrawAllWhenOutOfSeason: should withdraw 2+ tokens when there is no season', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token1 = this.tokenA;
    const token2 = this.tokenB;

    const balance1 = _10000();
    await token1.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token1.setBalance(user, balance1);

    const balance2 = new BN('10000000000');
    await token2.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token2.setBalance(user, balance2);

    const deposit1 = _100();
    const deposit2 = new BN('125000000');

    let result = await this.yieldFarming.beginFarming(user, user, token1.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token1.address, depositedAmount: deposit1},
    );
    (await token1.balanceOf(user)).should.be.bignumber.eq(balance1.sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token1.address)).should.be.bignumber.eq(deposit1);

    result = await this.yieldFarming.beginFarming(user, user, token2.address, deposit2, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token2.address, depositedAmount: deposit2},
    );
    (await token2.balanceOf(user)).should.be.bignumber.eq(balance2.sub(deposit2));
    (await this.yieldFarming.balanceOf(user, token2.address)).should.be.bignumber.eq(deposit2);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    await endFarmSeason(this);

    result = await this.yieldFarming.withdrawAllWhenOutOfSeason(user, receiver, {from: user});
    expectEvent(
      result,
      'WithdrawOutOfSeason',
      {owner: user, token: token1.address, recipient: receiver, amount: deposit1},
    );
    (await this.yieldFarming.balanceOf(user, token1.address)).should.be.bignumber.eq(new BN('0'));
    (await token1.balanceOf(receiver)).should.be.bignumber.eq(deposit1);
  });

  it('withdrawAllWhenOutOfSeason: should withdraw with a trusted spender', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await this.yieldFarming.approve(spender, true, {from: user});

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: spender});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    await endFarmSeason(this);

    result = await this.yieldFarming.withdrawAllWhenOutOfSeason(user, receiver, {from: spender});
    expectEvent(
      result,
      'WithdrawOutOfSeason',
      {owner: user, token: token.address, recipient: receiver, amount: deposit1},
    );
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(new BN('0'));
    (await token.balanceOf(receiver)).should.be.bignumber.eq(deposit1);
  });

  it('withdrawAllWhenOutOfSeason: should not withdraw during a season', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    await expectRevert(
      this.yieldFarming.withdrawAllWhenOutOfSeason(user, receiver, {from: user}),
      'DMGYieldFarming: FARM_IS_ACTIVE',
    );
  });

  it('withdrawAllWhenOutOfSeason: should not withdraw using an untrusted spender', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    await endFarmSeason(this);

    await expectRevert(
      this.yieldFarming.withdrawAllWhenOutOfSeason(user, receiver, {from: spender}),
      'DMGYieldFarmingV1: UNAPPROVED',
    );
  });

  it('withdrawByTokenWhenOutOfSeason: should withdraw when the there is no active season', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    await endFarmSeason(this);

    result = await this.yieldFarming.withdrawByTokenWhenOutOfSeason(user, receiver, token.address, {from: user});
    expectEvent(
      result,
      'WithdrawOutOfSeason',
      {owner: user, token: token.address, recipient: receiver, amount: deposit1},
    );
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(new BN('0'));
    (await token.balanceOf(receiver)).should.be.bignumber.eq(deposit1);
  });

  it('withdrawByTokenWhenOutOfSeason: should withdraw using a trusted spender when the there is a season', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await this.yieldFarming.approve(spender, true, {from: user});

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: spender});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    await endFarmSeason(this);

    result = await this.yieldFarming.withdrawByTokenWhenOutOfSeason(user, receiver, token.address, {from: spender});
    expectEvent(
      result,
      'WithdrawOutOfSeason',
      {owner: user, token: token.address, recipient: receiver, amount: deposit1},
    );
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(new BN('0'));
    (await token.balanceOf(receiver)).should.be.bignumber.eq(deposit1);
  });

  it('withdrawByTokenWhenOutOfSeason: should withdraw when there is an active season and removed token', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    (await this.yieldFarming.isFarmActive()).should.eq(true);

    result = await this.yieldFarming.withdrawByTokenWhenOutOfSeason(user, receiver, this.tokenC.address, {from: user});
    expectEvent(
      result,
      'WithdrawOutOfSeason',
      {owner: user, token: this.tokenC.address, recipient: receiver, amount: new BN('0')},
    );
    (await this.yieldFarming.balanceOf(user, this.tokenC.address)).should.be.bignumber.eq(new BN('0'));
    (await token.balanceOf(receiver)).should.be.bignumber.eq(new BN('0'));
  });

  it('withdrawByTokenWhenOutOfSeason: should not withdraw when there is an active season', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    (await this.yieldFarming.isFarmActive()).should.eq(true);

    await expectRevert(
      this.yieldFarming.withdrawByTokenWhenOutOfSeason(user, receiver, token.address, {from: user}),
      'DMGYieldFarmingV1::withdrawByTokenWhenOutOfSeason: FARM_ACTIVE_OR_TOKEN_SUPPORTED',
    );
  });

  it('withdrawByTokenWhenOutOfSeason: should not withdraw when there is an untrusted spender', async () => {
    // Prices are $1.01 and $0.99
    await startFarmSeason(this);
    const token = this.tokenA;

    await token.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await token.setBalance(user, _10000());
    const deposit1 = _100();
    let result = await this.yieldFarming.beginFarming(user, user, token.address, deposit1, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: token.address, depositedAmount: deposit1},
    );
    (await token.balanceOf(user)).should.be.bignumber.eq(_10000().sub(deposit1));
    (await this.yieldFarming.balanceOf(user, token.address)).should.be.bignumber.eq(deposit1);

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    (await this.yieldFarming.isFarmActive()).should.eq(true);

    await expectRevert(
      this.yieldFarming.withdrawByTokenWhenOutOfSeason(user, receiver, token.address, {from: spender}),
      'DMGYieldFarmingV1: UNAPPROVED',
    );
  });

});