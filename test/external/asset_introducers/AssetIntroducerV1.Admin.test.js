const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {expectRevert, expectEvent, BN} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1} = require('../../helpers/DmmTokenTestHelpers');
const {doAssetIntroductionV1BeforeEach} = require('../../helpers/AssetIntroductionHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, owner] = accounts;

describe('AssetIntroducerV1.Admin', () => {
  const ownerError = 'OwnableOrGuardian: UNAUTHORIZED_OWNER_OR_GUARDIAN';
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

    await doAssetIntroductionV1BeforeEach(this, contract, web3);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('setBaseURI: should set baseURI', async () => {
    let baseURI = 'hello-there';
    let result = await this.assetIntroducer.setBaseURI(baseURI, {from: owner});
    expectEvent(
      result,
      'BaseURIChanged',
      {'newBaseURI': baseURI},
    );
    (await this.assetIntroducer.baseURI()).should.eq(baseURI);

    baseURI = 'hello-there-2';
    result = await this.assetIntroducer.setBaseURI(baseURI, {from: guardian});
    expectEvent(
      result,
      'BaseURIChanged',
      {'newBaseURI': baseURI},
    );
    (await this.assetIntroducer.baseURI()).should.eq(baseURI);
  });

  it('setBaseURI: should not set baseURI for non-owner or guardian', async () => {
    const baseURI = 'hello-there';
    const result = this.assetIntroducer.setBaseURI(baseURI, {from: user});
    await expectRevert(result, ownerError);
  });


  it('setAssetIntroducerPrice: should work for owner or guardian', async () => {
    const countryCode = 'USA';
    const introducerType = '0';
    let priceUsd = new BN('125000000000000000000000');
    const result = await this.assetIntroducer.setAssetIntroducerPrice(countryCode, introducerType, priceUsd, {from: owner});
    expectEvent(
      result,
      'AssetIntroducerPriceChanged',
      {
        countryCode: web3.utils.sha3(countryCode),
        introducerType: introducerType,
        oldPriceUsd: '0',
        newPriceUsd: priceUsd,
      }
    );

    const oneEth = new BN('1000000000000000000');
    const discountFactor = await this.assetIntroducer.getAssetIntroducerDiscount();
    priceUsd = priceUsd.mul(oneEth.sub(discountFactor)).div(oneEth);
    (await this.assetIntroducer.getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(countryCode, introducerType)).should.be.bignumber.eq(priceUsd);
  });

  it('setAssetIntroducerPrice: should revert for non-owner or guardian', async () => {
    const countryCode = 'USA';
    const introducerType = '0';
    const priceUsd = '125000000000000000000000';
    const result = this.assetIntroducer.setAssetIntroducerPrice(countryCode, introducerType, priceUsd, {from: user});
    await expectRevert(result, ownerError);
  });

  it('createAssetIntroducersForPrimaryMarket: should work for owner', async () => {
    const countryCodes = ['USA'];
    const introducerTypes = ['0'];
    const priceUsd = '125000000000000000000000';

    await this.assetIntroducer.setAssetIntroducerPrice(countryCodes[0], introducerTypes[0], priceUsd, {from: owner});

    let tokenIdHash = web3.utils.soliditySha3({
      v: web3.utils.fromUtf8(countryCodes[0]),
      t: 'bytes3'
    }, {v: introducerTypes[0], t: 'uint8'}, {v: '0', t: 'uint'});
    let tokenId = new BN(tokenIdHash.substring(2), 'hex');
    (await this.assetIntroducer.getNextAssetIntroducerTokenId(countryCodes[0], introducerTypes[0])).should.be.bignumber.eq(tokenId);

    let serialNumber = '1';
    let result = await this.assetIntroducer.createAssetIntroducersForPrimaryMarket(countryCodes, introducerTypes, {from: owner});
    expectEvent(
      result,
      'AssetIntroducerCreated',
      {tokenId, 'countryCode': countryCodes[0], introducerType: introducerTypes[0], serialNumber},
    );

    serialNumber = '2';
    tokenIdHash = web3.utils.soliditySha3({
      v: web3.utils.fromUtf8(countryCodes[0]),
      t: 'bytes3'
    }, {v: introducerTypes[0], t: 'uint8'}, {v: '1', t: 'uint'});
    tokenId = new BN(tokenIdHash.substring(2), 'hex');
    result = await this.assetIntroducer.createAssetIntroducersForPrimaryMarket(countryCodes, introducerTypes, {from: owner});
    expectEvent(
      result,
      'AssetIntroducerCreated',
      {tokenId, 'countryCode': countryCodes[0], introducerType: introducerTypes[0], serialNumber},
    );

    const assetIntroducer2 = await this.assetIntroducer.getAssetIntroducerByTokenId(tokenId);
    (assetIntroducer2.countryCode).should.be.eq(web3.utils.fromUtf8(countryCodes[0]));
    (assetIntroducer2.dmgLocked).should.be.bignumber.eq(new BN('0'));
    (assetIntroducer2.dollarAmountToManage).should.bignumber.eq(new BN('0'));
    (assetIntroducer2.introducerType).should.be.eq(introducerTypes[0]);
    (assetIntroducer2.isAllowedToWithdrawFunds).should.be.eq(false);
    (assetIntroducer2.isOnSecondaryMarket).should.be.eq(false);
    (assetIntroducer2.serialNumber).should.be.bignumber.eq(new BN(serialNumber));
    (assetIntroducer2.tokenId).should.be.bignumber.eq(tokenId);
  });

  it('createAssetIntroducersForPrimaryMarket: should revert if price is not set yet', async () => {
    const countryCodes = ['USA'];
    const introducerTypes = ['0'];
    const result = this.assetIntroducer.createAssetIntroducersForPrimaryMarket(countryCodes, introducerTypes, {from: owner});
    await expectRevert(result, 'AssetIntroducerV1Lib::createAssetIntroducersForPrimaryMarket: PRICE_NOT_SET');
  });

  it('createAssetIntroducersForPrimaryMarket: should revert for non-owner or guardian', async () => {
    const countryCodes = ['USA'];
    const introducerTypes = ['0'];
    const result = this.assetIntroducer.createAssetIntroducersForPrimaryMarket(countryCodes, introducerTypes, {from: user});
    await expectRevert(result, ownerError);
  });

  it('setDollarAmountToManageByTokenId: should work for owner or guardian', async () => {
    const countryCode = 'USA';
    const introducerType = '0';
    const priceUsd = '125000000000000000000000';

    await this.assetIntroducer.setAssetIntroducerPrice(countryCode, introducerType, priceUsd, {from: owner});

    let tokenIdHash = web3.utils.soliditySha3({v: web3.utils.fromUtf8(countryCode), t: 'bytes3'}, {
      v: introducerType,
      t: 'uint8'
    }, {v: '0', t: 'uint'});
    let tokenId = new BN(tokenIdHash.substring(2), 'hex');
    (await this.assetIntroducer.getNextAssetIntroducerTokenId(countryCode, introducerType)).should.be.bignumber.eq(tokenId);

    await this.assetIntroducer.createAssetIntroducersForPrimaryMarket([countryCode], [introducerType], {from: owner})

    const dollarAmountToManage = new BN('100000000000000000000000');
    const result = await this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, dollarAmountToManage, {from: owner});
    expectEvent(
      result,
      'AssetIntroducerDollarAmountToManageChange',
      {
        tokenId,
        oldDollarAmountToManage: '0',
        newDollarAmountToManage: dollarAmountToManage,
      }
    );

    (await this.assetIntroducer.getDollarAmountToManageByTokenId(tokenId)).should.be.bignumber.eq(dollarAmountToManage);
  });

  it('setDollarAmountToManageByTokenId: should revert for non-owner or guardian', async () => {
    const countryCode = 'USA';
    const introducerType = '0';
    const priceUsd = '125000000000000000000000';

    await this.assetIntroducer.setAssetIntroducerPrice(countryCode, introducerType, priceUsd, {from: owner});
    await this.assetIntroducer.createAssetIntroducersForPrimaryMarket([countryCode], [introducerType], {from: owner})

    const tokenIdHash = web3.utils.soliditySha3({v: web3.utils.fromUtf8(countryCode), t: 'bytes3'}, {
      v: introducerType,
      t: 'uint8'
    }, {v: '0', t: 'uint'});
    const tokenId = new BN(tokenIdHash.substring(2), 'hex');
    const dollarAmountToManage = new BN('100000000000000000000000');
    const result = this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, dollarAmountToManage, {from: user});
    await expectRevert(result, ownerError);
  });

  it('setDollarAmountToManageByCountryCodeAndIntroducerType: should work for owner or guardian', async () => {
    const countryCode = 'USA';
    const introducerType = '0';
    const priceUsd = '125000000000000000000000';

    await this.assetIntroducer.setAssetIntroducerPrice(countryCode, introducerType, priceUsd, {from: owner});

    let tokenIdHash = web3.utils.soliditySha3({v: web3.utils.fromUtf8(countryCode), t: 'bytes3'}, {
      v: introducerType,
      t: 'uint8'
    }, {v: '0', t: 'uint'});
    let tokenId = new BN(tokenIdHash.substring(2), 'hex');

    await this.assetIntroducer.createAssetIntroducersForPrimaryMarket([countryCode, countryCode], [introducerType, introducerType], {from: owner})

    const dollarAmountToManage = new BN('100000000000000000000000');
    const result = await this.assetIntroducer.setDollarAmountToManageByCountryCodeAndIntroducerType(countryCode, introducerType, dollarAmountToManage, {from: owner});
    expectEvent(
      result,
      'AssetIntroducerDollarAmountToManageChange',
      {
        tokenId,
        oldDollarAmountToManage: '0',
        newDollarAmountToManage: dollarAmountToManage,
      }
    );

    tokenIdHash = web3.utils.soliditySha3({v: web3.utils.fromUtf8(countryCode), t: 'bytes3'}, {
      v: introducerType,
      t: 'uint8'
    }, {v: '1', t: 'uint'});
    tokenId = new BN(tokenIdHash.substring(2), 'hex');
    expectEvent(
      result,
      'AssetIntroducerDollarAmountToManageChange',
      {
        tokenId,
        oldDollarAmountToManage: '0',
        newDollarAmountToManage: dollarAmountToManage,
      }
    );

    (await this.assetIntroducer.getDollarAmountToManageByTokenId(tokenId)).should.be.bignumber.eq(dollarAmountToManage);
  });

  it('setDollarAmountToManageByCountryCodeAndIntroducerType: should revert for non-owner or guardian', async () => {
    const countryCode = 'USA';
    const introducerType = '0';
    const priceUsd = '125000000000000000000000';

    await this.assetIntroducer.setAssetIntroducerPrice(countryCode, introducerType, priceUsd, {from: owner});
    await this.assetIntroducer.createAssetIntroducersForPrimaryMarket([countryCode], [introducerType], {from: owner})

    const tokenIdHash = web3.utils.soliditySha3({v: web3.utils.fromUtf8(countryCode), t: 'bytes3'}, {
      v: introducerType,
      t: 'uint8'
    }, {v: '0', t: 'uint'});
    const tokenId = new BN(tokenIdHash.substring(2), 'hex');
    const dollarAmountToManage = new BN('100000000000000000000000');
    const result = this.assetIntroducer.setDollarAmountToManageByCountryCodeAndIntroducerType(countryCode, introducerType, dollarAmountToManage, {from: user});
    await expectRevert(result, ownerError);
  });

  it('setAssetIntroducerDiscount: should work for owner or guardian', async () => {
    const result = await this.assetIntroducer.setAssetIntroducerDiscount(this.dmmController.address, {from: owner});
    expectEvent(
      result,
      'AssetIntroducerDiscountChanged',
      {
        oldAssetIntroducerDiscount: this.assetIntroducerDiscount.address,
        newAssetIntroducerDiscount: this.dmmController.address,
      }
    );

    (await this.assetIntroducer.assetIntroducerDiscount()).should.be.eq(this.dmmController.address);
  });

  it('setAssetIntroducerDiscount: should revert for non-owner or guardian', async () => {
    const result = this.assetIntroducer.setAssetIntroducerDiscount(this.dmmController.address, {from: user});
    await expectRevert(result, ownerError);
  });

});