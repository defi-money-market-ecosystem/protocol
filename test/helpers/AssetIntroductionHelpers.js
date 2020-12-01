const {ZERO_ADDRESS} = require('@openzeppelin/test-helpers/src/constants');

const {web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
const web3Config = require('@openzeppelin/test-helpers/src/config/web3');
require('chai').should();

const {setupLoader} = require('@openzeppelin/contract-loader');

const {
  BN,
  constants,
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');

const ethereumJsUtil = require('ethereumjs-util');

const {_001, _1, _100, _10000} = require('./DmmTokenTestHelpers');

const doAssetIntroductionV1BeforeEach = async (thisInstance, contracts, web3, provider) => {
  const ERC20Mock = contracts.fromArtifact('ERC20Mock');
  const AssetIntroducerProxy = contracts.fromArtifact('AssetIntroducerProxy');
  const AssetIntroducerVotingLib = contracts.fromArtifact('AssetIntroducerVotingLib');
  const AssetIntroducerV1UserLib = contracts.fromArtifact('AssetIntroducerV1UserLib');
  const AssetIntroducerV1AdminLib = contracts.fromArtifact('AssetIntroducerV1AdminLib');
  const AssetIntroducerV1 = contracts.fromArtifact('AssetIntroducerV1');
  const DmmControllerMock = contracts.fromArtifact('DmmControllerMock');
  const ERC721TokenLib = contracts.fromArtifact('ERC721TokenLib');
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

  thisInstance.dmgToken = await ERC20Mock.new(thisInstance.admin, {from: thisInstance.admin});
  await thisInstance.dmgToken.setBalance(thisInstance.owner, _10000());

  thisInstance.underlyingTokenValuator = await UnderlyingTokenValuatorMock.new(
    [thisInstance.dmgToken.address],
    ['50000000'],
    ['8'],
    {from: thisInstance.admin}
  );

  thisInstance.dmmController = await DmmControllerMock.new(
    constants.ZERO_ADDRESS,
    thisInstance.underlyingTokenValuator.address,
    [],
    [],
    '62500000000000000',
    {from: thisInstance.admin},
  );

  thisInstance.baseURI = 'https://api.defimoneymarket.com/v1/asset-introducers/';

  thisInstance.proxy = await AssetIntroducerProxy.new(
    thisInstance.implementation.address,
    thisInstance.admin,
    // Begin IMPL initializer
    thisInstance.baseURI,
    thisInstance.guardian,
    thisInstance.guardian,
    thisInstance.dmgToken.address,
    thisInstance.dmmController.address,
    thisInstance.underlyingTokenValuator.address,
  );
  console.log('    AssetIntroducerProxy gas used to deploy: ', (await web3.eth.getTransactionReceipt(thisInstance.proxy.transactionHash)).gasUsed.toString());
  console.log('');

  thisInstance.assetIntroducer = await contracts.fromArtifact('AssetIntroducerV1', thisInstance.proxy.address)
  thisInstance.contract = thisInstance.assetIntroducer;

  await thisInstance.assetIntroducer.transferOwnership(thisInstance.owner, {from: thisInstance.guardian});
}

module.exports = {
  doAssetIntroductionV1BeforeEach,
}