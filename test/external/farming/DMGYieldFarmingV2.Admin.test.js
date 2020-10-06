const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {BN, constants, expectRevert, expectEvent, time} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1, _10, _100, _10000} = require('../../helpers/DmmTokenTestHelpers');
const {doYieldFarmingExternalProxyBeforeEach} = require('../../helpers/YieldFarmingHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, owner, user] = accounts;

describe('DMGYieldFarmingV2.Admin', () => {
  const NOT_OWNER_ERROR = 'DMGYieldFarmingV2:: UNAUTHORIZED';
  const timeBuffer = new BN('2');
  const UniswapLpToken = new BN('1');
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

  it('approveGloballyTrustedProxy: should add proxy if owner', async () => {
    (await this.yieldFarming.isGloballyTrustedProxy(this.tokenC.address)).should.eq(false);

    const result = await this.yieldFarming.approveGloballyTrustedProxy(
      this.tokenC.address,
      true,
      {from: owner}
    );
    expectEvent(
      result,
      'GlobalProxySet',
      {
        proxy: this.tokenC.address,
        isTrusted: true,
      }
    );

    (await this.yieldFarming.isGloballyTrustedProxy(this.tokenC.address)).should.eq(true);
  });

  it('approveGloballyTrustedProxy: should not add proxy if not owner', async () => {
    (await this.yieldFarming.isGloballyTrustedProxy(this.tokenC.address)).should.eq(false);
    await expectRevert(
      this.yieldFarming.approveGloballyTrustedProxy(this.tokenC.address, true, {from: user}),
      NOT_OWNER_ERROR,
    );
  });

  it('addAllowableToken: should add token if owner', async () => {
    const decimals = '18';
    const points = new BN('400');
    const fees = new BN('100');
    const result = await this.yieldFarming.addAllowableToken(
      this.tokenC.address,
      this.underlyingTokenC.address,
      decimals,
      points,
      fees,
      UniswapLpToken,
      {from: owner}
    );
    expectEvent(
      result,
      'TokenAdded',
      {
        token: this.tokenC.address,
        underlyingToken: this.underlyingTokenC.address,
        underlyingTokenDecimals: decimals,
        points: points,
        fees: fees,
      }
    );

    (await this.yieldFarming.getRewardPointsByToken(this.tokenC.address)).should.be.bignumber.eq(new BN('400'));
    (await this.yieldFarming.getTokenDecimalsByToken(this.tokenC.address)).should.be.bignumber.eq(new BN('18'));
    (await this.yieldFarming.getTokenIndexPlusOneByToken(this.tokenC.address)).should.be.bignumber.eq(new BN('3'));
  });

  it('addAllowableToken: should not add token if not owner', async () => {
    const decimals = '18';
    const points = new BN('400');
    const fees = new BN('50');
    await expectRevert(
      this.yieldFarming.addAllowableToken(
        this.tokenC.address,
        this.underlyingTokenC.address,
        decimals,
        points,
        fees,
        UniswapLpToken,
        {from: user}
      ),
      NOT_OWNER_ERROR,
    );
  });

  it('addAllowableToken: should not add token if it already exists', async () => {
    const decimals = '18';
    const points = new BN('400');
    const fees = new BN('100');
    const result = await this.yieldFarming.addAllowableToken(
      this.tokenC.address,
      this.underlyingTokenC.address,
      decimals,
      points,
      fees,
      UniswapLpToken,
      {from: owner}
    );
    expectEvent(
      result,
      'TokenAdded',
      {
        token: this.tokenC.address,
        underlyingToken: this.underlyingTokenC.address,
        underlyingTokenDecimals: decimals,
        points: points,
        fees: fees,
      }
    );

    await expectRevert(
      this.yieldFarming.addAllowableToken(
        this.tokenC.address,
        this.underlyingTokenC.address,
        decimals,
        points,
        fees,
        UniswapLpToken,
        {from: owner}
      ),
      'DMGYieldFarmingV2::addAllowableToken: TOKEN_ALREADY_SUPPORTED'
    );
  });

  it('removeAllowableToken: should remove token if owner', async () => {
    const result = await this.yieldFarming.removeAllowableToken(this.tokenA.address, {from: owner});
    expectEvent(
      result,
      'TokenRemoved',
      {token: this.tokenA.address,}
    );
  });

  it('removeAllowableToken: should not remove token if not owner', async () => {
    await expectRevert(
      this.yieldFarming.removeAllowableToken(this.tokenA.address, {from: user}),
      NOT_OWNER_ERROR,
    );
  });

  it('removeAllowableToken: should not remove token if it does not already exist', async () => {
    await expectRevert(
      this.yieldFarming.removeAllowableToken(this.tokenC.address, {from: owner}),
      'DMGYieldFarmingV2::removeAllowableToken: TOKEN_NOT_SUPPORTED'
    );
  });

  it('removeAllowableToken: should not remove token if there is an active season', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    const result = await this.yieldFarming.beginFarmingSeason(_100(), {from: owner});
    expectEvent(result, 'FarmSeasonBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    await expectRevert(
      this.yieldFarming.removeAllowableToken(this.tokenC.address, {from: owner}),
      'DMGYieldFarmingV2:: FARM_IS_ACTIVE'
    );
  });

  it('setRewardPointsByTokens: should set points if sent by owner', async () => {
    const points = new BN('500');
    const token = this.tokenA.address;
    const result = await this.yieldFarming.setRewardPointsByTokens([token], [points], {from: owner});
    expectEvent(result, 'RewardPointsSet', {token: token, points});
    (await this.yieldFarming.getRewardPointsByToken(token)).should.be.bignumber.eq(points);
  });

  it('setRewardPointsByTokens: should fail if not sent by owner', async () => {
    const points = new BN('500');
    await expectRevert(
      this.yieldFarming.setRewardPointsByTokens([this.tokenA.address], [points], {from: user}),
      NOT_OWNER_ERROR
    );
  });

  it('setRewardPointsByTokens: should fail if points is 0', async () => {
    const points = new BN('0');
    await expectRevert(
      this.yieldFarming.setRewardPointsByTokens([this.tokenA.address], [points], {from: owner}),
      'DMGYieldFarmingV2::_verifyPoints: INVALID_POINTS'
    );
  });

  it('setDmgGrowthCoefficient: should set coefficient if sent by owner', async () => {
    const coefficient = new BN('100000000000000000');
    const result = await this.yieldFarming.setDmgGrowthCoefficient(coefficient, {from: owner});
    expectEvent(result, 'DmgGrowthCoefficientSet', {coefficient});
    (await this.yieldFarming.dmgGrowthCoefficient()).should.be.bignumber.eq(coefficient);
  });

  it('setDmgGrowthCoefficient: should fail if not sent by owner', async () => {
    const coefficient = new BN('100000000000000000');
    await expectRevert(
      this.yieldFarming.setDmgGrowthCoefficient(coefficient, {from: user}),
      NOT_OWNER_ERROR
    );
  });

  it('setDmgGrowthCoefficient: should fail if coefficient is 0', async () => {
    const coefficient = new BN('0');
    await expectRevert(
      this.yieldFarming.setDmgGrowthCoefficient(coefficient, {from: owner}),
      'DMGYieldFarmingV2::_verifyDmgGrowthCoefficient: INVALID_GROWTH_COEFFICIENT'
    );
  });

  it('beginFarmingSeason: should succeed if the system is idle', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    const result = await this.yieldFarming.beginFarmingSeason(_100(), {from: owner});
    expectEvent(result, 'FarmSeasonBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(_10000().sub(_100()));
  });

  it('beginFarmingSeason: should fail if there is a season active', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    const result = await this.yieldFarming.beginFarmingSeason(_100(), {from: owner});
    expectEvent(result, 'FarmSeasonBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    await expectRevert(
      this.yieldFarming.beginFarmingSeason(_100(), {from: owner}),
      'DMGYieldFarmingV2::beginFarmingSeason: FARM_ALREADY_ACTIVE',
    );
  });

  it('beginFarmingSeason: should fail if not called by owner or guardian', async () => {
    await expectRevert(this.yieldFarming.beginFarmingSeason(_100(), {from: user}), NOT_OWNER_ERROR);
  });

  it('endActiveFarmingSeason: should succeed if the farm is active and sent by owner', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    let result = await this.yieldFarming.beginFarmingSeason(_100(), {from: owner});
    expectEvent(result, 'FarmSeasonBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(_10000().sub(_100()));

    result = await this.yieldFarming.endActiveFarmingSeason(guardian, {from: owner});
    expectEvent(result, 'FarmSeasonEnd', {seasonIndex: new BN('2'), dustRecipient: guardian});
    (await this.dmgToken.balanceOf(guardian)).should.be.bignumber.eq(_100());
  });

  it('endActiveFarmingSeason: should succeed if the farm is active and sent by guardian', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    let result = await this.yieldFarming.beginFarmingSeason(_100(), {from: owner});
    expectEvent(result, 'FarmSeasonBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(_10000().sub(_100()));

    result = await this.yieldFarming.endActiveFarmingSeason(guardian, {from: guardian});
    expectEvent(result, 'FarmSeasonEnd', {seasonIndex: new BN('2'), dustRecipient: guardian});
    (await this.dmgToken.balanceOf(guardian)).should.be.bignumber.eq(_100());
  });

  it('endActiveFarmingSeason: should succeed if the farm is depleted and called by a user', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    let result = await this.yieldFarming.beginFarmingSeason(_10000(), {from: owner});
    expectEvent(result, 'FarmSeasonBegun', {seasonIndex: new BN('2'), dmgAmount: _10000()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(new BN('0'));

    await this.underlyingTokenA.setBalance(user, _1(), {from: user});
    await this.underlyingTokenA_2.setBalance(user, _1(), {from: user});

    await this.underlyingTokenA.approve(this.uniswapV2Router.address, constants.MAX_UINT256, {from: user});
    await this.underlyingTokenA_2.approve(this.uniswapV2Router.address, constants.MAX_UINT256, {from: user});

    await this.uniswapV2Router.addLiquidity(
      this.underlyingTokenA.address,
      this.underlyingTokenA_2.address,
      _1(),
      _1(),
      _1(),
      _1(),
      user,
      (await time.latest()).add(timeBuffer),
      {from: user}
    );

    await this.tokenA.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    const tokenABalance = await this.tokenA.balanceOf(user);
    result = await this.yieldFarming.beginFarming(user, user, this.tokenA.address, tokenABalance, {from: user});
    expectEvent(
      result,
      'BeginFarming',
      {owner: user, token: this.tokenA.address, depositedAmount: tokenABalance},
    );

    const _10Seconds = new BN('10');
    await time.increase(_10Seconds);

    result = await this.yieldFarming.endFarmingByToken(user, user, this.tokenA.address, {from: user});
    expectEvent(
      result,
      'HarvestFeePaid',
      {owner: user, token: this.tokenA.address, tokenAmountToConvert: tokenABalance.mul(new BN('50')).div(new BN('10000'))},
    );
    expectEvent(
      result,
      'EndFarming',
      {
        owner: user,
        token: this.tokenA.address,
        withdrawnAmount: tokenABalance.mul(new BN('10000').sub(new BN('50'))).div(new BN('10000')),
      },
    );
    const endFarmingEvent = result.logs[1].args.earnedDmgAmount;

    result = await this.yieldFarming.endActiveFarmingSeason(guardian, {from: owner});
    expectEvent(result, 'FarmSeasonEnd', {seasonIndex: new BN('2'), dustRecipient: guardian});
    (await this.dmgToken.balanceOf(guardian)).should.be.bignumber.eq(_10000().sub(endFarmingEvent));
  });

  it('endActiveFarmingSeason: should fail if the farm is active and sent by a user', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    let result = await this.yieldFarming.beginFarmingSeason(_100(), {from: owner});
    expectEvent(result, 'FarmSeasonBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(_10000().sub(_100()));

    await expectRevert(
      this.yieldFarming.endActiveFarmingSeason(user, {from: user}),
      'DMGYieldFarmingV2::endActiveFarmingSeason: FARM_ACTIVE_OR_INVALID_SENDER'
    );
  });

});