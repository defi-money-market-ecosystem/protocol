const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {BN, constants, expectRevert, expectEvent, time} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _100, _10000} = require('../../helpers/DmmTokenTestHelpers');
const {doYieldFarmingBeforeEach} = require('../../helpers/YieldFarmingHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, owner, user] = accounts;

describe('DMGYieldFarmingV1.Admin', () => {
  const NOT_OWNER_ERROR = 'DMGYieldFarmingData: NOT_OWNER';
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

    await doYieldFarmingBeforeEach(this, contract, web3);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    snapshotId = await resetChain(provider, snapshotId);
  });

  it('addAllowableToken: should add token if owner', async () => {
    const decimals = '18';
    const points = new BN('400');
    const result = await this.yieldFarming.addAllowableToken(
      this.tokenC.address,
      this.underlyingTokenC.address,
      decimals,
      points,
      {from: owner}
    );
    expectEvent(
      result,
      'TokenAdded',
      {
        token: this.tokenC.address,
        underlyingToken: this.underlyingTokenC.address,
        underlyingTokenDecimals: decimals,
        points: points
      }
    );

    (await this.yieldFarming.getRewardPointsByToken(this.tokenC.address)).should.be.bignumber.eq(new BN('400'));
    (await this.yieldFarming.getTokenDecimalsByToken(this.tokenC.address)).should.be.bignumber.eq(new BN('18'));
    (await this.yieldFarming.getTokenIndexPlusOneByToken(this.tokenC.address)).should.be.bignumber.eq(new BN('3'));
  });

  it('addAllowableToken: should not add token if not owner', async () => {
    const decimals = '18';
    const points = new BN('400');
    await expectRevert(
      this.yieldFarming.addAllowableToken(
        this.tokenC.address,
        this.underlyingTokenC.address,
        decimals,
        points,
        {from: user}
      ),
      NOT_OWNER_ERROR,
    );
  });

  it('addAllowableToken: should not add token if it already exists', async () => {
    const decimals = '18';
    const points = new BN('400');
    const result = await this.yieldFarming.addAllowableToken(
      this.tokenC.address,
      this.underlyingTokenC.address,
      decimals,
      points,
      {from: owner}
    );
    expectEvent(
      result,
      'TokenAdded',
      {
        token: this.tokenC.address,
        underlyingToken: this.underlyingTokenC.address,
        underlyingTokenDecimals: decimals,
        points: points
      }
    );

    await expectRevert(
      this.yieldFarming.addAllowableToken(
        this.tokenC.address,
        this.underlyingTokenC.address,
        decimals,
        points,
        {from: owner}
      ),
      'DMGYieldFarming::addAllowableToken: TOKEN_ALREADY_SUPPORTED'
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
      'DMGYieldFarming::removeAllowableToken: TOKEN_NOT_SUPPORTED'
    );
  });

  it('removeAllowableToken: should not remove token if there is an active season', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    const result = await this.yieldFarming.beginFarmingCampaign(_100(), {from: owner});
    expectEvent(result, 'FarmCampaignBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    await expectRevert(
      this.yieldFarming.removeAllowableToken(this.tokenC.address, {from: owner}),
      'DMGYieldFarming: FARM_IS_ACTIVE'
    );
  });

  it('setRewardPointsByToken: should set points if sent by owner', async () => {
    const points = new BN('500');
    const token = this.tokenA.address;
    const result = await this.yieldFarming.setRewardPointsByToken(token, points, {from: owner});
    expectEvent(result, 'RewardPointsSet', {token: token, points});
    (await this.yieldFarming.getRewardPointsByToken(token)).should.be.bignumber.eq(points);
  });

  it('setRewardPointsByToken: should fail if not sent by owner', async () => {
    const points = new BN('500');
    await expectRevert(
      this.yieldFarming.setRewardPointsByToken(this.tokenA.address, points, {from: user}),
      NOT_OWNER_ERROR
    )
  });

  it('setRewardPointsByToken: should fail if points is 0', async () => {
    const points = new BN('0');
    await expectRevert(
      this.yieldFarming.setRewardPointsByToken(this.tokenA.address, points, {from: owner}),
      'DMGYieldFarming::_verifyPoints: INVALID_POINTS'
    )
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
    )
  });

  it('setDmgGrowthCoefficient: should fail if coefficient is 0', async () => {
    const coefficient = new BN('0');
    await expectRevert(
      this.yieldFarming.setDmgGrowthCoefficient(coefficient, {from: owner}),
      'DMGYieldFarming::_verifyDmgGrowthCoefficient: INVALID_GROWTH_COEFFICIENT'
    )
  });

  // beginFarmingCampaign

  it('beginFarmingCampaign: should succeed if the system is idle', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    const result = await this.yieldFarming.beginFarmingCampaign(_100(), {from: owner});
    expectEvent(result, 'FarmCampaignBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(_10000().sub(_100()));
  });

  it('beginFarmingCampaign: should fail if there is a season active', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    const result = await this.yieldFarming.beginFarmingCampaign(_100(), {from: owner});
    expectEvent(result, 'FarmCampaignBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    await expectRevert(
      this.yieldFarming.beginFarmingCampaign(_100(), {from: owner}),
      'DMGYieldFarming::beginFarmingCampaign: FARM_ALREADY_ACTIVE',
    );
  });

  it('beginFarmingCampaign: should fail if called by guardian', async () => {
    await expectRevert(this.yieldFarming.beginFarmingCampaign(_100(), {from: guardian}), NOT_OWNER_ERROR);
  });

  it('beginFarmingCampaign: should fail if not called by owner', async () => {
    await expectRevert(this.yieldFarming.beginFarmingCampaign(_100(), {from: guardian}), NOT_OWNER_ERROR);
  });

  it('endActiveFarmingCampaign: should succeed if the farm is active and sent by owner', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    let result = await this.yieldFarming.beginFarmingCampaign(_100(), {from: owner});
    expectEvent(result, 'FarmCampaignBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(_10000().sub(_100()));

    result = await this.yieldFarming.endActiveFarmingCampaign(guardian, {from: owner});
    expectEvent(result, 'FarmCampaignEnd', {seasonIndex: new BN('2'), dustRecipient: guardian});
    (await this.dmgToken.balanceOf(guardian)).should.be.bignumber.eq(_100());
  });

  it('endActiveFarmingCampaign: should succeed if the farm is active and sent by guardian', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    let result = await this.yieldFarming.beginFarmingCampaign(_100(), {from: owner});
    expectEvent(result, 'FarmCampaignBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(_10000().sub(_100()));

    result = await this.yieldFarming.endActiveFarmingCampaign(guardian, {from: guardian});
    expectEvent(result, 'FarmCampaignEnd', {seasonIndex: new BN('2'), dustRecipient: guardian});
    (await this.dmgToken.balanceOf(guardian)).should.be.bignumber.eq(_100());
  });

  it('endActiveFarmingCampaign: should succeed if the farm is depleted and called by a user', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    let result = await this.yieldFarming.beginFarmingCampaign(_100(), {from: owner});
    expectEvent(result, 'FarmCampaignBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(_10000().sub(_100()));

    await this.tokenA.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: user});
    await this.tokenA.setBalance(user, _10000());
    result = await this.yieldFarming.beginFarming(user, this.tokenA.address, _10000(), {from: user});
    (result.receipt.status).should.eq(true)

    const _100Seconds = new BN('100');
    await time.increase(_100Seconds);

    result = await this.yieldFarming.endFarmingByToken(user, user, this.tokenA.address, {from: user});
    expectEvent(
      result,
      'EndFarming',
      {owner: user, token: this.tokenA.address, withdrawnAmount: _10000(), earnedDmgAmount: _100()},
    );

    result = await this.yieldFarming.endActiveFarmingCampaign(guardian, {from: user});
    expectEvent(result, 'FarmCampaignEnd', {seasonIndex: new BN('2'), dustRecipient: guardian});
    (await this.dmgToken.balanceOf(guardian)).should.be.bignumber.eq(new BN('0'));
  });

  it('endActiveFarmingCampaign: should fail if the farm is active and sent by a user', async () => {
    await this.dmgToken.approve(this.yieldFarming.address, constants.MAX_UINT256, {from: owner});
    let result = await this.yieldFarming.beginFarmingCampaign(_100(), {from: owner});
    expectEvent(result, 'FarmCampaignBegun', {seasonIndex: new BN('2'), dmgAmount: _100()});

    (await this.yieldFarming.isFarmActive()).should.eq(true);
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(_10000().sub(_100()));

    await expectRevert(
      this.yieldFarming.endActiveFarmingCampaign(user, {from: user}),
      'DMGYieldFarming: FARM_ACTIVE or INVALID_SENDER'
    )
  });

});