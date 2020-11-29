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
  const AssetIntroducerV1Lib = contracts.fromArtifact('AssetIntroducerV1Lib');
  const AssetIntroducerV1 = contracts.fromArtifact('AssetIntroducerV1');
  const DmmControllerMock = contracts.fromArtifact('DmmControllerMock');
  const UnderlyingTokenValuatorMock = contracts.fromArtifact('UnderlyingTokenValuatorMock');

  const assetIntroducerVotingLib = await AssetIntroducerVotingLib.new();
  const assetIntroducerV1Lib = await AssetIntroducerV1Lib.new();

  await AssetIntroducerV1.detectNetwork();
  await AssetIntroducerV1.link('AssetIntroducerVotingLib', assetIntroducerVotingLib.address);
  await AssetIntroducerV1.link('AssetIntroducerV1Lib', assetIntroducerV1Lib.address);

  thisInstance.implementation = await AssetIntroducerV1.new();

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

  thisInstance.proxy = await AssetIntroducerProxy.new(
    thisInstance.implementation.address,
    thisInstance.admin,
    // Begin IMPL initializer
    thisInstance.guardian,
    thisInstance.guardian,
    thisInstance.dmgToken.address,
    thisInstance.dmmController.address,
    thisInstance.underlyingTokenValuator.address,
    'https://api.defimoneymarket.com/v1/asset-introducers/'
  );

  thisInstance.assetIntroducer = await contracts.fromArtifact('AssetIntroducerV1', thisInstance.proxy.address)
  thisInstance.contract = thisInstance.assetIntroducer;

  await thisInstance.assetIntroducer.transferOwnership(thisInstance.owner, {from: thisInstance.guardian});
}

module.exports = {
  doAssetIntroductionV1BeforeEach,
}