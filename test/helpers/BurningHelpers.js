const {ZERO_ADDRESS} = require('@openzeppelin/test-helpers/src/constants');

const {web3} = require('@openzeppelin/test-environment');
const web3Config = require('@openzeppelin/test-helpers/src/config/web3');
require('chai').should();

const {setupLoader} = require('@openzeppelin/contract-loader');

const {constants} = require('@openzeppelin/test-helpers');

const ethereumJsUtil = require('ethereumjs-util');

const {_1, _10, _100, _10000} = require('./DmmTokenTestHelpers');

const unsiwapCoreDirectory = 'node_modules/@uniswap/v2-core/build/contracts'

const doBurningBeforeEach = async (thisInstance, contracts, web3, provider) => {
  web3Config.getWeb3 = () => web3;

  const DMGBurnerV1 = contracts.fromArtifact('DMGBurnerV1');
  const DMGBurnerProxy = contracts.fromArtifact('DMGBurnerProxy');
  const DMGToken = contracts.fromArtifact('DMGToken');
  const ERC20Mock = contracts.fromArtifact('ERC20Mock');
  const StringHelpers = contracts.fromArtifact('StringHelpers');
  const WETHMock = contracts.fromArtifact('WETHMock');
  const UniswapV2Router = contracts.fromArtifact('UniswapV2Router02');

  await Promise.all(
    [
      UniswapV2Router.detectNetwork(),
      DMGBurnerV1.detectNetwork(),
    ]
  );

  const stringHelpers = await StringHelpers.new();
  await DMGBurnerV1.link("StringHelpers", stringHelpers.address);

  thisInstance.tokenA = await WETHMock.new({from: thisInstance.admin});
  await thisInstance.tokenA.deposit({from: thisInstance.admin, value: _10000()});

  thisInstance.tokenB = await ERC20Mock.new({from: thisInstance.admin});
  await thisInstance.tokenB.setBalance(thisInstance.admin, _10000(), {from: thisInstance.admin});

  const uniswapCoreLoader = setupLoader({provider, artifactsDir: unsiwapCoreDirectory, defaultGas: 8e6});
  const UniswapV2Factory = uniswapCoreLoader.truffle.fromArtifact('UniswapV2Factory');
  thisInstance.uniswapFactory = await UniswapV2Factory.new(thisInstance.admin, {from: thisInstance.admin});

  thisInstance.uniswapV2Router = await UniswapV2Router.new(
    thisInstance.uniswapFactory.address,
    thisInstance.tokenA.address,
    {from: thisInstance.admin},
  )

  thisInstance.dmgToken = await DMGToken.new(thisInstance.admin, _10000(), {from: thisInstance.admin});

  thisInstance.tokenA.approve(thisInstance.uniswapV2Router.address, constants.MAX_UINT256, {from: thisInstance.admin});
  thisInstance.tokenB.approve(thisInstance.uniswapV2Router.address, constants.MAX_UINT256, {from: thisInstance.admin});
  thisInstance.dmgToken.approve(thisInstance.uniswapV2Router.address, constants.MAX_UINT256, {from: thisInstance.admin});

  await thisInstance.uniswapV2Router.addLiquidity(
    thisInstance.tokenA.address,
    thisInstance.tokenB.address,
    _1(),
    _10(),
    _1(),
    _1(),
    thisInstance.admin,
    (new Date().getTime() + 10000).toString(),
    {from: thisInstance.admin},
  );
  await thisInstance.uniswapV2Router.addLiquidity(
    thisInstance.tokenA.address,
    thisInstance.dmgToken.address,
    _1(),
    _100(),
    _1(),
    _1(),
    thisInstance.admin,
    (new Date().getTime() + 10000).toString(),
    {from: thisInstance.admin},
  );

  thisInstance.implementation = await DMGBurnerV1.new({from: thisInstance.admin});

  thisInstance.proxy = await DMGBurnerProxy.new(
    thisInstance.implementation.address,
    thisInstance.admin,
    // Begin IMPL initializer
    thisInstance.uniswapV2Router.address,
    thisInstance.dmgToken.address,
    {from: thisInstance.admin}
  );

  thisInstance.burner = await contracts.fromArtifact('DMGBurnerV1', thisInstance.proxy.address)
  thisInstance.contract = thisInstance.burner;

  thisInstance.tokenA.approve(thisInstance.proxy.address, constants.MAX_UINT256, {from: thisInstance.admin});
  thisInstance.tokenB.approve(thisInstance.proxy.address, constants.MAX_UINT256, {from: thisInstance.admin});
  thisInstance.dmgToken.approve(thisInstance.proxy.address, constants.MAX_UINT256, {from: thisInstance.admin});

  const tokens = [
    thisInstance.tokenA.address,
    thisInstance.tokenB.address,
    thisInstance.dmgToken.address,
  ];
  await thisInstance.burner.enableTokens(tokens, {from: thisInstance.guardian});
};

module.exports = {
  doBurningBeforeEach,
}