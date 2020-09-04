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

const {_1, _100, _10000} = require('./DmmTokenTestHelpers');

const unsiwapDirectory = 'node_modules/@uniswap/v2-core/build/contracts'

const doYieldFarmingExternalProxyBeforeEach = async (thisInstance, contracts, web3, provider) => {
  const ERC20Mock = contracts.fromArtifact('ERC20Mock');
  const WETHMock = contracts.fromArtifact('WETHMock');
  const DMGYieldFarmingFundingProxy = contracts.fromArtifact('DMGYieldFarmingFundingProxy');

  thisInstance.underlyingTokenA = await WETHMock.new({from: thisInstance.admin});
  thisInstance.weth = thisInstance.underlyingTokenA;
  thisInstance.underlyingTokenB = await ERC20Mock.new({from: thisInstance.admin});
  thisInstance.underlyingTokenC = await ERC20Mock.new({from: thisInstance.admin});

  thisInstance.underlyingTokenA_2 = await ERC20Mock.new({from: thisInstance.admin});
  thisInstance.underlyingTokenB_2 = await ERC20Mock.new({from: thisInstance.admin});
  thisInstance.underlyingTokenC_2 = await ERC20Mock.new({from: thisInstance.admin});

  const loader = setupLoader({provider, artifactsDir: unsiwapDirectory, defaultGas: 8e6});

  const UniswapV2Factory = loader.truffle.fromArtifact('UniswapV2Factory');
  thisInstance.uniswapFactory = await UniswapV2Factory.new(thisInstance.admin, {from: thisInstance.admin});

  const resultA = await thisInstance.uniswapFactory.createPair(thisInstance.underlyingTokenA_2.address, thisInstance.underlyingTokenA.address, {from: thisInstance.admin});
  thisInstance.tokenA = await contracts.fromArtifact('IUniswapV2Pair', resultA.logs[0].args.pair)

  const resultB = await thisInstance.uniswapFactory.createPair(thisInstance.underlyingTokenB_2.address, thisInstance.underlyingTokenB.address, {from: thisInstance.admin});
  thisInstance.tokenB = await contracts.fromArtifact('IUniswapV2Pair', resultB.logs[0].args.pair)

  const resultC = await thisInstance.uniswapFactory.createPair(thisInstance.underlyingTokenC_2.address, thisInstance.underlyingTokenC.address, {from: thisInstance.admin});
  thisInstance.tokenC = await contracts.fromArtifact('IUniswapV2Pair', resultC.logs[0].args.pair)

  await doYieldFarmingBeforeEach(thisInstance, contracts, web3);

  thisInstance.yieldFarmingFundingProxy = await DMGYieldFarmingFundingProxy.new(
    thisInstance.yieldFarming.address,
    thisInstance.uniswapFactory.address,
    thisInstance.weth.address,
  );
  thisInstance.contract = thisInstance.yieldFarmingFundingProxy;

  (await thisInstance.contract.getPair(thisInstance.underlyingTokenA_2.address, thisInstance.underlyingTokenA.address)).should.eq(thisInstance.tokenA.address);
  (await thisInstance.contract.getPair(thisInstance.underlyingTokenB_2.address, thisInstance.underlyingTokenB.address)).should.eq(thisInstance.tokenB.address);
  (await thisInstance.contract.getPair(thisInstance.underlyingTokenC_2.address, thisInstance.underlyingTokenC.address)).should.eq(thisInstance.tokenC.address);

  await thisInstance.yieldFarmingFundingProxy.enableTokens(
    [thisInstance.tokenA.address, thisInstance.tokenB.address, thisInstance.tokenC.address],
    [thisInstance.yieldFarming.address, thisInstance.yieldFarming.address, thisInstance.yieldFarming.address],
  );
};

const doYieldFarmingBeforeEach = async (thisInstance, contracts, web3) => {
  web3Config.getWeb3 = () => web3;

  const DMGYieldFarmingV1 = contracts.fromArtifact('DMGYieldFarmingV1');
  const DMGYieldFarmingProxy = contracts.fromArtifact('DMGYieldFarmingProxy');
  const ERC20Mock = contracts.fromArtifact('ERC20Mock');
  const DmmControllerMock = contracts.fromArtifact('DmmControllerMock');
  const UnderlyingTokenValuatorMock = contracts.fromArtifact('UnderlyingTokenValuatorMock');
  const StringHelpers = contracts.fromArtifact('StringHelpers');

  await Promise.all(
    [
      DMGYieldFarmingV1.detectNetwork(),
    ]
  );

  const stringHelpers = await StringHelpers.new();
  await DMGYieldFarmingV1.link("StringHelpers", stringHelpers.address);

  thisInstance.tokenA = thisInstance.tokenA || await ERC20Mock.new({from: thisInstance.admin});
  thisInstance.tokenB = thisInstance.tokenB || await ERC20Mock.new({from: thisInstance.admin});
  thisInstance.tokenC = thisInstance.tokenC || await ERC20Mock.new({from: thisInstance.admin});

  if (!thisInstance.underlyingTokenA) {
    thisInstance.underlyingTokenA = thisInstance.underlyingTokenA || await ERC20Mock.new({from: thisInstance.admin});
    await thisInstance.underlyingTokenA.setBalance(thisInstance.tokenA.address, _10000());
  }

  if (!thisInstance.underlyingTokenB) {
    thisInstance.underlyingTokenB = thisInstance.underlyingTokenB || await ERC20Mock.new({from: thisInstance.admin});
    await thisInstance.underlyingTokenB.setBalance(thisInstance.tokenB.address, '10000000000'); // 10,000 (6 decimals)
  }

  if (!thisInstance.underlyingTokenC) {
    thisInstance.underlyingTokenC = await ERC20Mock.new({from: thisInstance.admin});
    await thisInstance.underlyingTokenC.setBalance(thisInstance.tokenC.address, _10000());
  }

  thisInstance.dmgToken = await ERC20Mock.new(thisInstance.admin, {from: thisInstance.admin});
  await thisInstance.dmgToken.setBalance(thisInstance.owner, _10000());

  thisInstance.underlyingTokenValuator = await UnderlyingTokenValuatorMock.new(
    [thisInstance.underlyingTokenA.address, thisInstance.underlyingTokenB.address],
    ['101000000', '99000000'], // $1.01 and $0.99
    ['8', '8'],
  );
  thisInstance.dmmController = await DmmControllerMock.new(
    ZERO_ADDRESS,
    thisInstance.underlyingTokenValuator.address,
    ZERO_ADDRESS,
    '0',
  );

  thisInstance.allowableTokens = [thisInstance.tokenA.address, thisInstance.tokenB.address];
  thisInstance.underlyingTokens = [thisInstance.underlyingTokenA.address, thisInstance.underlyingTokenB.address];

  thisInstance.implementation = await DMGYieldFarmingV1.new({from: thisInstance.admin});

  thisInstance.proxy = await DMGYieldFarmingProxy.new(
    thisInstance.implementation.address,
    thisInstance.admin,
    // Begin IMPL initializer
    thisInstance.dmgToken.address,
    thisInstance.guardian,
    thisInstance.dmmController.address,
    _1() /* dmgGrowthCoefficient */,
    thisInstance.allowableTokens,
    thisInstance.underlyingTokens,
    [18, 6],
    [new BN('100'), new BN('300')],
  );

  thisInstance.yieldFarming = await contracts.fromArtifact('DMGYieldFarmingV1', thisInstance.proxy.address)
  thisInstance.contract = thisInstance.yieldFarming;

  await thisInstance.yieldFarming.transferOwnership(thisInstance.owner, {from: thisInstance.guardian});
};

const startFarmSeason = async (thisInstance, index) => {
  await thisInstance.dmgToken.approve(thisInstance.yieldFarming.address, constants.MAX_UINT256, {from: thisInstance.owner});
  let result = await thisInstance.yieldFarming.beginFarmingCampaign(_100(), {from: thisInstance.owner});
  expectEvent(result, 'FarmCampaignBegun', {seasonIndex: index || new BN('2'), dmgAmount: _100()});
}

const endFarmSeason = async (thisInstance, index) => {
  await thisInstance.dmgToken.approve(thisInstance.yieldFarming.address, constants.MAX_UINT256, {from: thisInstance.owner});
  let result = await thisInstance.yieldFarming.endActiveFarmingCampaign(thisInstance.owner, {from: thisInstance.owner});
  expectEvent(result, 'FarmCampaignEnd', {seasonIndex: index || new BN('2'), dustRecipient: thisInstance.owner});
}

module.exports = {
  doYieldFarmingExternalProxyBeforeEach,
  doYieldFarmingBeforeEach,
  startFarmSeason,
  endFarmSeason
}