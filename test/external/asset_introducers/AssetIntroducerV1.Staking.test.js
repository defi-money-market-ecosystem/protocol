const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {constants, expectRevert, expectEvent, BN, time} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1} = require('../../helpers/DmmTokenTestHelpers');
const {
  PRICE_USA_AFFILIATE,
  doAssetIntroducerV1BeforeEach,
  doDmgIncentivePoolBeforeEach,
  doAssetIntroducerStakingV1BeforeEach,
  createNFTs,
  ONE_ETH,
  TWELVE_MONTHS_ENUM,
  EIGHTEEN_MONTHS_ENUM,
} = require('../../helpers/AssetIntroductionHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, user2, owner, other] = accounts;

describe('AssetIntroducerV1.Staking', () => {
  let snapshotId;
  const dmmTokenId = 1;
  before(async () => {
    this.admin = admin;
    this.guardian = guardian;
    this.owner = owner;
    this.user = user;
    this.user2 = user2;

    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);

    await doAssetIntroducerV1BeforeEach(this, contract, web3);
    await doDmgIncentivePoolBeforeEach(this, contract, web3);
    await doAssetIntroducerStakingV1BeforeEach(this, contract, web3);
    await createNFTs(this);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('isReady: should be true', async () => {
    (await this.assetIntroducerStaking.isReady()).should.eq(true);
  })

  it('getStakeAmountByTokenIdAndDmmTokenId: should work', async () => {
    const tokenId = this.tokenIds[0];
    const discount = await this.assetIntroducer.getAssetIntroducerDiscount();
    const stakeAmount = await this.assetIntroducerStaking.getStakeAmountByTokenIdAndDmmTokenId(tokenId, dmmTokenId);
    const expectedUsdValue = new BN(PRICE_USA_AFFILIATE).mul(ONE_ETH.sub(discount)).div(ONE_ETH);
    (stakeAmount).should.be.bignumber.eq(expectedUsdValue);
  })

  it('getDmgPriceByTokenIdAndStakingDuration: should work', async () => {
    const tokenId = this.tokenIds[0];
    const nonStakingDiscount = await this.assetIntroducer.getAssetIntroducerDiscount();
    const totalDiscount1 = await this.assetIntroducerStaking.getTotalDiscountByStakingDuration(TWELVE_MONTHS_ENUM);
    let originalExpectedPrice = await this.assetIntroducer.getAssetIntroducerPriceDmgByTokenId(tokenId);
    let expectedPriceWithStakingDiscount = originalExpectedPrice.mul(ONE_ETH).div(ONE_ETH.sub(nonStakingDiscount)).mul(ONE_ETH.sub(totalDiscount1)).div(ONE_ETH);
    let dmgPriceAndAdditionalDiscount = await this.assetIntroducerStaking.getAssetIntroducerPriceDmgByTokenIdAndStakingDuration(tokenId, TWELVE_MONTHS_ENUM);
    dmgPriceAndAdditionalDiscount['0'].should.be.bignumber.eq(expectedPriceWithStakingDiscount);
    dmgPriceAndAdditionalDiscount['1'].should.be.bignumber.eq(totalDiscount1.sub(nonStakingDiscount));

    const totalDiscount2 = await this.assetIntroducerStaking.getTotalDiscountByStakingDuration(EIGHTEEN_MONTHS_ENUM);
    (totalDiscount2.gt(totalDiscount1)).should.be.eq(true);

    originalExpectedPrice = await this.assetIntroducer.getAssetIntroducerPriceDmgByTokenId(tokenId);
    expectedPriceWithStakingDiscount = originalExpectedPrice.mul(ONE_ETH).div(ONE_ETH.sub(nonStakingDiscount)).mul(ONE_ETH.sub(totalDiscount2)).div(ONE_ETH);
    dmgPriceAndAdditionalDiscount = await this.assetIntroducerStaking.getAssetIntroducerPriceDmgByTokenIdAndStakingDuration(tokenId, EIGHTEEN_MONTHS_ENUM);

    dmgPriceAndAdditionalDiscount['0'].should.be.bignumber.eq(expectedPriceWithStakingDiscount);
    dmgPriceAndAdditionalDiscount['1'].should.be.bignumber.eq(totalDiscount2.sub(nonStakingDiscount));

    totalDiscount1.should.be.bignumber.gt(new BN('949999900000000000'));
    totalDiscount2.should.be.bignumber.gt(new BN('989999900000000000'));
  })

  it('getDiscount: should work after expiration of 18 months', async () => {
    // move time forward by 19 months
    await time.increase(new BN('86400').mul(new BN('30').mul(new BN('19'))));
    const totalDiscount1 = await this.assetIntroducerStaking.getTotalDiscountByStakingDuration(TWELVE_MONTHS_ENUM);
    const totalDiscount2 = await this.assetIntroducerStaking.getTotalDiscountByStakingDuration(EIGHTEEN_MONTHS_ENUM);

    (totalDiscount1).should.be.bignumber.eq(new BN('250000000000000000'));
    (totalDiscount2).should.be.bignumber.eq(new BN('500000000000000000'));
  })

  it('buyAssetIntroducerSlot: should work', async () => {
    await buyAssetIntroducerSlot(this.tokenIds[6]);
  })

  it('buyAssetIntroducerSlot: should work for multiple', async () => {
    const {stakeBalance: stakeBalance1} = await buyAssetIntroducerSlot(this.tokenIds[5]);
    const {stakeBalance2} = await buyAssetIntroducerSlot(this.tokenIds[6], stakeBalance1);
  })

  it('withdrawStake: should work', async () => {
    const tokenId = this.tokenIds[5];
    const {stakeBalance: stakeBalance1} = await buyAssetIntroducerSlot(tokenId);
    await time.increase(new BN(86400).mul(new BN(10000)));

    const result = await this.assetIntroducerStaking.withdrawStake({from: user});
    expectEvent(
      result,
      'UserEndStaking',
      {user: user, tokenId: tokenId, dmmToken: this.underlyingToken.address, amount: stakeBalance1}
    );

    let stakes = await this.assetIntroducerStaking.getUserStakesByAddress(user);
    (stakes[stakes.length - 1].tokenId).should.bignumber.eq(tokenId);
    (stakes[stakes.length - 1].isWithdrawn).should.eq(true);
    (stakes[stakes.length - 1].mToken).should.eq(this.underlyingToken.address);
    (stakes[stakes.length - 1].amount).should.bignumber.eq(stakeBalance1);

    stakes = await this.assetIntroducerStaking.getActiveUserStakesByAddress(user);
    stakes.length.should.be.eq(0);

    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.eq(this.defaultBalance);
  })

  it('withdrawStake: should work with multiple stakes', async () => {
    let tokenId = this.tokenIds[5];
    const {stakeBalance: stakeBalance1} = await buyAssetIntroducerSlot(tokenId);
    await time.increase(new BN(86400).mul(new BN(10000)));

    const result = await this.assetIntroducerStaking.withdrawStake({from: user});
    expectEvent(
      result,
      'UserEndStaking',
      {user: user, tokenId: tokenId, dmmToken: this.underlyingToken.address, amount: stakeBalance1}
    );

    let stakes = await this.assetIntroducerStaking.getUserStakesByAddress(user);
    (stakes[stakes.length - 1].tokenId).should.bignumber.eq(tokenId);
    (stakes[stakes.length - 1].isWithdrawn).should.eq(true);
    (stakes[stakes.length - 1].mToken).should.eq(this.underlyingToken.address);
    (stakes[stakes.length - 1].amount).should.bignumber.eq(stakeBalance1);

    stakes = await this.assetIntroducerStaking.getActiveUserStakesByAddress(user);
    stakes.length.should.be.eq(0);

    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.eq(this.defaultBalance);

    tokenId = this.tokenIds[6];
    const {stakeBalance: stakeBalance2} = await buyAssetIntroducerSlot(tokenId);

    stakes = await this.assetIntroducerStaking.getUserStakesByAddress(user);
    stakes.length.should.be.eq(2);

    (stakes[0].isWithdrawn).should.eq(true);

    (stakes[1].tokenId).should.bignumber.eq(tokenId);
    (stakes[1].isWithdrawn).should.eq(false);
    (stakes[1].mToken).should.eq(this.underlyingToken.address);

    (stakes[stakes.length - 1].amount).should.bignumber.eq(stakeBalance2);
    stakes = await this.assetIntroducerStaking.getActiveUserStakesByAddress(user);
    stakes.length.should.be.eq(1);
  })

  it('withdrawStake: should work with multiple active stakes', async () => {
    let tokenId = this.tokenIds[5];
    const {stakeBalance: stakeBalance1} = await buyAssetIntroducerSlot(tokenId);
    tokenId = this.tokenIds[6];
    const {stakeBalance: stakeBalance2} = await buyAssetIntroducerSlot(tokenId, stakeBalance1);
    await time.increase(new BN(86400).mul(new BN(10000)));

    await this.assetIntroducerStaking.withdrawStake({from: user});

    let stakes = await this.assetIntroducerStaking.getUserStakesByAddress(user);
    stakes.length.should.be.eq(2);
    (stakes[0].tokenId).should.bignumber.eq(this.tokenIds[5]);
    (stakes[1].tokenId).should.bignumber.eq(this.tokenIds[6]);

    for (let i = 0; i < stakes.length; i++) {
      (stakes[i].isWithdrawn).should.eq(true);
      (stakes[i].mToken).should.eq(this.underlyingToken.address);
    }

    (stakes[0].amount).should.bignumber.eq(stakeBalance1);
    (stakes[1].amount).should.bignumber.eq(stakeBalance2.sub(stakeBalance1));

    stakes = await this.assetIntroducerStaking.getActiveUserStakesByAddress(user);
    stakes.length.should.be.eq(0);

    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.eq(this.defaultBalance);
    (await this.assetIntroducerStaking.balanceOf(user, this.underlyingToken.address)).should.be.bignumber.eq(new BN(0));
  })

  const buyAssetIntroducerSlot = async (tokenId, previousStakeBalance) => {
    await this.dmgToken.approve(this.assetIntroducerStaking.address, constants.MAX_UINT256, {from: user});
    await this.underlyingToken.approve(this.assetIntroducerStaking.address, constants.MAX_UINT256, {from: user});

    const userDmgBalanceBefore = await this.dmgToken.balanceOf(user);
    const poolDmgBalanceBefore = await this.dmgToken.balanceOf(this.incentivePool.address);

    const userUnderlyingBalanceBefore = await this.underlyingToken.balanceOf(user);

    const result = await this.assetIntroducerStaking.buyAssetIntroducerSlot(tokenId, dmmTokenId, TWELVE_MONTHS_ENUM, {from: user});
    const fullStakeAmountUsd = await this.assetIntroducer.getAssetIntroducerPriceUsdByTokenId(tokenId);
    const underlyingTokenPriceStandardized = new BN(this.underlyingTokenPrice).mul(new BN(10).pow(new BN(10)));
    const fullStakeAmountToken = fullStakeAmountUsd.mul(ONE_ETH).div(underlyingTokenPriceStandardized);
    const fullPriceDmgAndAdditionalDiscount = await this.assetIntroducerStaking.getAssetIntroducerPriceDmgByTokenIdAndStakingDuration(tokenId, TWELVE_MONTHS_ENUM);
    const fullPriceDmg = fullPriceDmgAndAdditionalDiscount['0']
    const userPriceDmg = fullPriceDmg.div(new BN('2'));
    const unlockTimestamp = (await time.latest()).add(new BN('86400').mul(new BN(30)).mul(new BN(12)));
    expectEvent(
      result,
      'IncentiveDmgUsed',
      {tokenId: tokenId, buyer: user, amount: userPriceDmg}
    );
    expectEvent(
      result,
      'UserBeginStaking',
      {
        user: user,
        tokenId: tokenId,
        dmmToken: this.underlyingToken.address,
        amount: fullStakeAmountToken,
        unlockTimestamp: unlockTimestamp
      }
    );

    (await this.assetIntroducer.ownerOf(tokenId)).should.be.eq(user);
    (await this.dmgToken.balanceOf(user)).should.be.bignumber.eq(userDmgBalanceBefore.sub(userPriceDmg));
    (await this.dmgToken.balanceOf(this.incentivePool.address)).should.be.bignumber.eq(poolDmgBalanceBefore.sub(fullPriceDmg.sub(userPriceDmg)));

    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.eq(userUnderlyingBalanceBefore.sub(fullStakeAmountToken));

    const stakeBalance = await this.assetIntroducerStaking.balanceOf(user, this.underlyingToken.address);
    (stakeBalance).should.be.bignumber.eq(fullStakeAmountToken.add(previousStakeBalance || new BN(0)));

    const stakes = await this.assetIntroducerStaking.getActiveUserStakesByAddress(user);
    (stakes[stakes.length - 1].tokenId).should.bignumber.eq(tokenId);
    (stakes[stakes.length - 1].isWithdrawn).should.eq(false);
    (stakes[stakes.length - 1].mToken).should.eq(this.underlyingToken.address);
    (stakes[stakes.length - 1].amount).should.bignumber.eq(fullStakeAmountToken);
    (stakes[stakes.length - 1].unlockTimestamp).should.bignumber.eq(unlockTimestamp);

    return {result, stakeBalance};
  }

});