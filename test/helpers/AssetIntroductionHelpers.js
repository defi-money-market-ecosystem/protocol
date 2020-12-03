const {ZERO_ADDRESS} = require('@openzeppelin/test-helpers/src/constants');

const {web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
const web3Config = require('@openzeppelin/test-helpers/src/config/web3');
require('chai').should();

const {setupLoader} = require('@openzeppelin/contract-loader');

const {
  BN,
  constants,
  ether,
  expectEvent,
  expectRevert,
  send,
} = require('@openzeppelin/test-helpers');

const ethereumJsUtil = require('ethereumjs-util');

const {_001, _1, _100, _10000} = require('./DmmTokenTestHelpers');

const doAssetIntroductionV1BeforeEach = async (thisInstance, contracts, web3, provider) => {
  const AssetIntroducerDiscountV1 = contracts.fromArtifact('AssetIntroducerDiscountV1');
  const AssetIntroducerProxy = contracts.fromArtifact('AssetIntroducerProxy');
  const AssetIntroducerVotingLib = contracts.fromArtifact('AssetIntroducerVotingLib');
  const AssetIntroducerV1UserLib = contracts.fromArtifact('AssetIntroducerV1UserLib');
  const AssetIntroducerV1AdminLib = contracts.fromArtifact('AssetIntroducerV1AdminLib');
  const AssetIntroducerV1 = contracts.fromArtifact('AssetIntroducerV1');
  const DMGTestToken = contracts.fromArtifact('DMGTestToken');
  const DmmControllerMock = contracts.fromArtifact('DmmControllerMock');
  const ERC20Mock = contracts.fromArtifact('ERC20Mock');
  const ERC721TokenLib = contracts.fromArtifact('ERC721TokenLib');
  const TestOpenSeaProxyRegistry = contracts.fromArtifact('TestOpenSeaProxyRegistry');
  const UnderlyingTokenValuatorMock = contracts.fromArtifact('UnderlyingTokenValuatorMock');

  console.log('');

  const assetIntroducerVotingLib = await AssetIntroducerVotingLib.new();
  console.log('    AssetIntroducerVotingLib gas used to deploy: ', (await web3.eth.getTransactionReceipt(assetIntroducerVotingLib.transactionHash)).gasUsed.toString());

  await ERC721TokenLib.detectNetwork();
  await ERC721TokenLib.link('AssetIntroducerVotingLib', assetIntroducerVotingLib.address);
  const erc721TokenLib = await ERC721TokenLib.new();
  console.log('    Erc721TokenLib gas used to deploy: ', (await web3.eth.getTransactionReceipt(erc721TokenLib.transactionHash)).gasUsed.toString());

  await AssetIntroducerV1AdminLib.detectNetwork();
  await AssetIntroducerV1AdminLib.link('ERC721TokenLib', erc721TokenLib.address);
  const assetIntroducerV1AdminLib = await AssetIntroducerV1AdminLib.new();
  console.log('    AssetIntroducerV1AdminLib gas used to deploy: ', (await web3.eth.getTransactionReceipt(assetIntroducerV1AdminLib.transactionHash)).gasUsed.toString());

  await AssetIntroducerV1UserLib.detectNetwork();
  await AssetIntroducerV1UserLib.link('AssetIntroducerVotingLib', assetIntroducerVotingLib.address);
  await AssetIntroducerV1UserLib.link('ERC721TokenLib', erc721TokenLib.address);
  const assetIntroducerV1UserLib = await AssetIntroducerV1UserLib.new();
  console.log('    AssetIntroducerV1UserLib gas used to deploy: ', (await web3.eth.getTransactionReceipt(assetIntroducerV1UserLib.transactionHash)).gasUsed.toString());

  await AssetIntroducerV1.detectNetwork();
  await AssetIntroducerV1.link('AssetIntroducerVotingLib', assetIntroducerVotingLib.address);
  await AssetIntroducerV1.link('AssetIntroducerV1UserLib', assetIntroducerV1UserLib.address);
  await AssetIntroducerV1.link('AssetIntroducerV1AdminLib', assetIntroducerV1AdminLib.address);
  await AssetIntroducerV1.link('ERC721TokenLib', erc721TokenLib.address);

  thisInstance.implementation = await AssetIntroducerV1.new();
  console.log('    AssetIntroducerV1 gas used to deploy: ', (await web3.eth.getTransactionReceipt(thisInstance.implementation.transactionHash)).gasUsed.toString());

  thisInstance.dmgToken = await DMGTestToken.new(thisInstance.admin, {from: thisInstance.admin});
  await thisInstance.dmgToken.setBalance(thisInstance.owner, _10000());

  thisInstance.underlyingToken = await ERC20Mock.new();

  thisInstance.dmgUsdPrice = '50000000';
  thisInstance.underlyingTokenPrice = '100000000';

  thisInstance.underlyingTokenValuator = await UnderlyingTokenValuatorMock.new(
    [thisInstance.dmgToken.address, thisInstance.underlyingToken.address],
    [thisInstance.dmgUsdPrice, thisInstance.underlyingTokenPrice], // $0.50, $1.00
    ['8', '8'],
    {from: thisInstance.admin}
  );

  thisInstance.dmmController = await DmmControllerMock.new(
    constants.ZERO_ADDRESS,
    thisInstance.underlyingTokenValuator.address,
    [thisInstance.underlyingToken.address],
    [thisInstance.underlyingToken.address],
    '62500000000000000',
    {from: thisInstance.admin},
  );

  thisInstance.assetIntroducerDiscount = await AssetIntroducerDiscountV1.new();

  thisInstance.baseURI = 'https://api.defimoneymarket.com/v1/asset-introducers/';
  thisInstance.openSeaProxyRegistry = await TestOpenSeaProxyRegistry.new();

  thisInstance.proxy = await AssetIntroducerProxy.new(
    thisInstance.implementation.address,
    thisInstance.admin,
    // Begin IMPL initializer
    thisInstance.baseURI,
    thisInstance.openSeaProxyRegistry.address,
    thisInstance.guardian,
    thisInstance.guardian,
    thisInstance.dmgToken.address,
    thisInstance.dmmController.address,
    thisInstance.underlyingTokenValuator.address,
    thisInstance.assetIntroducerDiscount.address,
  );
  console.log('    AssetIntroducerProxy gas used to deploy: ', (await web3.eth.getTransactionReceipt(thisInstance.proxy.transactionHash)).gasUsed.toString());
  console.log('');

  thisInstance.assetIntroducer = await contracts.fromArtifact('AssetIntroducerV1', thisInstance.proxy.address)
  thisInstance.contract = thisInstance.assetIntroducer;

  await thisInstance.assetIntroducer.transferOwnership(thisInstance.owner, {from: thisInstance.guardian});
};

const PRINCIPAL = 0;
const AFFILIATE = 1;

const PRICE_USA_AFFILIATE = '150000000000000000000000'; // $150,000
const PRICE_USA_PRINCIPAL = '250000000000000000000000'; // $250,000

const PRICE_CHN_AFFILIATE = '125000000000000000000000'; // $125,000
const PRICE_CHN_PRINCIPAL = '208000000000000000000000'; // $208,000

const PRICE_IND_AFFILIATE = '100000000000000000000000'; // $100,000
const PRICE_IND_PRINCIPAL = '166000000000000000000000'; // $166,000

const createNFTs = async (
  thisInstance,
  countryCodes = ['USA', 'USA', 'CHN', 'CHN', 'IND', 'IND', 'IND'],
  introducerTypes = [AFFILIATE, PRINCIPAL, AFFILIATE, PRINCIPAL, AFFILIATE, AFFILIATE, PRINCIPAL],
  pricesUsd = [PRICE_USA_AFFILIATE, PRICE_USA_PRINCIPAL, PRICE_CHN_AFFILIATE, PRICE_CHN_PRINCIPAL, PRICE_IND_AFFILIATE, PRICE_IND_AFFILIATE, PRICE_IND_PRINCIPAL]
) => {
  if (countryCodes.length === 0 || introducerTypes.length === 0) {
    throw 'lengths must be non-zero';
  }
  if (countryCodes.length !== introducerTypes.length) {
    throw 'lengths must match';
  }

  for (let i = 0; i < countryCodes.length; i++) {
    await thisInstance.assetIntroducer.setAssetIntroducerPrice(countryCodes[i], introducerTypes[i], pricesUsd[i], {from: thisInstance.owner});
  }

  await thisInstance.assetIntroducer.createAssetIntroducersForPrimaryMarket(countryCodes, introducerTypes, {from: thisInstance.owner});

  thisInstance.tokenIds = [];
  for (let i = 0; i < countryCodes.length; i++) {
    thisInstance.tokenIds.push((await thisInstance.assetIntroducer.tokenByIndex(i)).toString(10));
  }

  thisInstance.defaultBalance = new BN('100000000000000000000000000');
  await thisInstance.dmgToken.setBalance(thisInstance.user, thisInstance.defaultBalance);
  await thisInstance.dmgToken.setBalance(thisInstance.user2, thisInstance.defaultBalance);
  await thisInstance.dmgToken.setBalance(thisInstance.wallet.address, thisInstance.defaultBalance);

  await thisInstance.dmgToken.approve(thisInstance.assetIntroducer.address, constants.MAX_UINT256, {from: thisInstance.user});
  await thisInstance.dmgToken.approve(thisInstance.assetIntroducer.address, constants.MAX_UINT256, {from: thisInstance.user2});
  await send.ether(thisInstance.user, thisInstance.wallet.address, ether('1'));
  await thisInstance.dmgToken.approve(thisInstance.assetIntroducer.address, constants.MAX_UINT256, {from: thisInstance.wallet.address});

  thisInstance.purchaseResults = {};
  // Last one doesn't get purchased
  for (let i = 0; i < countryCodes.length - 2; i++) {
    let user;
    if (i < (countryCodes.length - 2) / 2) {
      user = thisInstance.user;
    } else {
      user = thisInstance.user2;
    }
    if (!thisInstance.purchaseResults[user]) {
      thisInstance.purchaseResults[user] = [];
    }
    thisInstance.purchaseResults[user].push(await thisInstance.assetIntroducer.buyAssetIntroducerSlot(thisInstance.tokenIds[i], {from: user}));
  }

};

module.exports = {
  doAssetIntroductionV1BeforeEach,
  createNFTs,
  PRICE_USA_PRINCIPAL,
  PRICE_USA_AFFILIATE,
  PRICE_CHN_PRINCIPAL,
  PRICE_CHN_AFFILIATE,
  PRICE_IND_PRINCIPAL,
  PRICE_IND_AFFILIATE,
  AFFILIATE,
  PRINCIPAL,
}