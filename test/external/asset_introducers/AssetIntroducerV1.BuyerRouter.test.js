const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {expectRevert, expectEvent, BN, constants} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1} = require('../../helpers/DmmTokenTestHelpers');
const {doAssetIntroducerV1BeforeEach, doAssetIntroducerV1BuyerRouterBeforeEach, doDmgIncentivePoolBeforeEach, createNFTs, AFFILIATE} = require('../../helpers/AssetIntroductionHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, user2, owner] = accounts;

describe('AssetIntroducerV1.BuyerRouter', () => {
  let snapshotId;
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
    await doAssetIntroducerV1BuyerRouterBeforeEach(this, contract, web3);

    await createNFTs(this);
    await this.dmgToken.burn(await this.dmgToken.balanceOf(owner), {from: owner});

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('isReady: should be true', async () => {
    (await this.buyerRouter.isReady()).should.be.eq(true);
  });

  it('withdrawDustTo: should work for owner', async () => {
    const amount = new BN('500');
    await this.dmgToken.setBalance(this.buyerRouter.address, amount);
    await this.buyerRouter.withdrawDustTo(this.dmgToken.address, owner, amount, {from: owner});
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(amount);
    (await this.dmgToken.balanceOf(this.buyerRouter.address)).should.be.bignumber.eq(new BN('0'));
  });

  it('withdrawDustTo: should not work for non-owner', async () => {
    const amount = new BN('500');
    await expectRevert.unspecified(this.buyerRouter.withdrawDustTo(this.dmgToken.address, owner, amount, {from: user}));
  });

  it('withdrawAllDustTo: should work for owner', async () => {
    const amount = new BN('500');
    await this.dmgToken.setBalance(this.buyerRouter.address, amount);
    await this.buyerRouter.withdrawAllDustTo(this.dmgToken.address, owner, {from: owner});
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(amount);
    (await this.dmgToken.balanceOf(this.buyerRouter.address)).should.be.bignumber.eq(new BN('0'));
  });

  it('withdrawAllDustTo: should not work for non-owner', async () => {
    await expectRevert.unspecified(this.buyerRouter.withdrawAllDustTo(owner, this.dmgToken.address, {from: user}));
  });

  it('getAssetIntroducerPriceUsdByTokenId: should work', async () => {
    const tokenId = this.tokenIds[0];
    (await this.buyerRouter.getAssetIntroducerPriceUsdByTokenId(tokenId))
      .should.be.bignumber.eq((await this.assetIntroducer.getAssetIntroducerPriceUsdByTokenId(tokenId)).div(new BN('2')));
  });

  it('getAssetIntroducerPriceDmgByTokenId: should work', async () => {
    const tokenId = this.tokenIds[0];
    (await this.buyerRouter.getAssetIntroducerPriceDmgByTokenId(tokenId))
      .should.be.bignumber.eq((await this.assetIntroducer.getAssetIntroducerPriceDmgByTokenId(tokenId)).div(new BN('2')));
  });

  it('getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType: should work', async () => {
    const countryCode = 'USA';
    const introducerType = AFFILIATE;
    (await this.buyerRouter.getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(countryCode, introducerType))
      .should.be.bignumber.eq((await this.assetIntroducer.getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(countryCode, introducerType)).div(new BN('2')));
  });

  it('getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType: should work', async () => {
    const countryCode = 'USA';
    const introducerType = AFFILIATE;
    (await this.buyerRouter.getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(countryCode, introducerType))
      .should.be.bignumber.eq((await this.assetIntroducer.getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(countryCode, introducerType)).div(new BN('2')));
  });

  it('buyAssetIntroducerSlot: should work', async () => {
    await this.dmgToken.approve(this.buyerRouter.address, constants.MAX_UINT256, {from: user});

    const userBalanceBefore = await this.dmgToken.balanceOf(user);
    const poolBalanceBefore = await this.dmgToken.balanceOf(this.incentivePool.address);

    const tokenId = this.tokenIds[6];
    const fullPriceDmg = await this.assetIntroducer.getAssetIntroducerPriceDmgByTokenId(tokenId);
    const userPriceDmg = await this.buyerRouter.getAssetIntroducerPriceDmgByTokenId(tokenId);
    const result = await this.buyerRouter.buyAssetIntroducerSlot(tokenId, {from: user});
    expectEvent(
      result,
      'IncentiveDmgUsed',
      {tokenId: tokenId, buyer: user, amount: userPriceDmg}
    );

    (await this.assetIntroducer.ownerOf(tokenId)).should.be.eq(user);
    (await this.dmgToken.balanceOf(user)).should.be.bignumber.eq(userBalanceBefore.sub(userPriceDmg));
    (await this.dmgToken.balanceOf(this.incentivePool.address)).should.be.bignumber.eq(poolBalanceBefore.sub(fullPriceDmg.sub(userPriceDmg)));
  });

});