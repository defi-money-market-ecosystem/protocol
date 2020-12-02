// const {dai, link, usdc, weth} = require('./DeployTokens');
const {BN} = require('ethereumjs-util');
const {callContract, deployContract} = require('../ContractUtils');
const {constants} = require('@openzeppelin/test-helpers');

global.interestRateImpl = null;
global.offChainAssetValuator = null;
global.offChainCurrencyValuator = null;
global.underlyingTokenValuator = null;
global.delayedOwner = null;
global.dmmEtherFactory = null;
global.dmmTokenFactory = null;
global.dmmBlacklist = null;
global.dmmController = null;

const _0_1 = new BN('100000000000000000'); // 0.1
const _0_01 = new BN('10000000000000000'); // 0.01
const _0_5 = new BN('500000000000000000'); // 0.5
const _1 = new BN('1000000000000000000'); // 1.0

const deployEcosystem = async (loader, environment, deployer, guardian) => {
  const DmmBlacklistable = loader.truffle.fromArtifact('DmmBlacklistable');
  const DmmController = loader.truffle.fromArtifact('DmmController');
  const DmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory');
  const DmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory');
  const InterestRateImplV1 = loader.truffle.fromArtifact('InterestRateImplV1');
  const OffChainAssetValuatorImplV2 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV2');
  const OffChainAssetValuatorProxy = loader.truffle.fromArtifact('OffChainAssetValuatorProxy');
  const OffChainCurrencyValuatorImplV2 = loader.truffle.fromArtifact('OffChainCurrencyValuatorImplV2');
  const OffChainCurrencyValuatorProxy = loader.truffle.fromArtifact('OffChainCurrencyValuatorProxy');
  const UnderlyingTokenValuatorImplV5 = loader.truffle.fromArtifact('UnderlyingTokenValuatorImplV5');
  const UnderlyingTokenValuatorProxy = loader.truffle.fromArtifact('UnderlyingTokenValuatorProxy');

  const DaiUsdAggregatorMock = loader.truffle.fromArtifact('DaiUsdAggregatorMock');
  const EthUsdAggregatorMockV2 = loader.truffle.fromArtifact('EthUsdAggregatorMockV2');
  const UsdcEthAggregatorMock = loader.truffle.fromArtifact('UsdcEthAggregatorMock');

  interestRateImplAddress = '0x6F2A3b2EFa07D264EA79Ce0b96d3173a8feAcD35';
  offChainAssetValuatorAddress = '0x4F9c3332D352F1ef22F010ba93A9653261e1634b';
  offChainCurrencyValuatorAddress = '0x826d758AF2FeD387ac15843327e143b2CAfE9047';
  underlyingTokenValuatorAddress = '0xaC7e5e3b589D55a43D62b90c6b4C4ef28Ea35573';
  dmmEtherFactoryAddress = '0x1186d7dFf910Aa6c74bb9af71539C668133034aC';
  dmmTokenFactoryAddress = '0x42665308F611b022df2fD48757A457BEC12BA668';
  dmmBlacklistAddress = '0x516d652E2f12876F5f0244aa661b1C262a2d96b1';
  dmmControllerAddress = '0x4CB120Dd1D33C9A3De8Bc15620C7Cd43418d77E2';

  let oracleAddress;
  let chainlinkJobId;

  if (environment === 'LOCAL') {
    oracleAddress = '0x0000000000000000000000000000000000000000';
    chainlinkJobId = '0x0000000000000000000000000000000000000000000000000000000000000000';
  } else if (environment === 'TESTNET') {
    oracleAddress = '0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e';
    chainlinkJobId = '0xd4b380b30cb64722b8843ead232985c300000000000000000000000000000000';
  } else if (environment === 'PRODUCTION') {
    oracleAddress = '0x0563fC575D5219C48E2Dfc20368FA4179cDF320D';
    chainlinkJobId = '0x2017ac2b3b5b37d2fbb5fef6193d6eef0cb50a4c6b3796c5b5c44bd1cca83aa0';
  } else {
    new Error('Invalid environment, found ' + environment);
  }

  await DmmEtherFactory.detectNetwork();
  await DmmTokenFactory.detectNetwork();
  await UnderlyingTokenValuatorImplV5.detectNetwork();

  console.log('Linking core ecosystem libraries...');
  await DmmEtherFactory.link('DmmTokenLibrary', dmmTokenLibrary.address);
  await DmmTokenFactory.link('DmmTokenLibrary', dmmTokenLibrary.address);
  await UnderlyingTokenValuatorImplV5.link('StringHelpers', stringHelpers.address);

  // linkContract(UnderlyingTokenValuatorImplV5, 'StringHelpers', stringHelpers.address);

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    interestRateImpl = loader.truffle.fromArtifact('InterestRateImplV1', '0x32Df47aB270a1ec1450fA4b7abdFa94eE6b5F2fA');
  } else if (environment !== 'PRODUCTION' && interestRateImplAddress !== null) {
    console.log('Deploying InterestRateImplV1...');
    interestRateImpl = await deployContract(InterestRateImplV1, [], deployer, 4e6);
  } else {
    interestRateImpl = loader.truffle.fromArtifact('InterestRateImplV1', interestRateImplAddress);
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    offChainAssetValuator = loader.truffle.fromArtifact('OffChainAssetValuatorProxy', '0x4F665bE185C3Ce125A7c81B2C6b26Be6fd58C780')
  } else if (environment !== 'PRODUCTION' || offChainAssetValuatorAddress === null) {
    console.log('Deploying OffChainAssetValuatorImplV2...');
    const implementation = await deployContract(OffChainAssetValuatorImplV2, [], deployer, 4e6);
    console.log('Deploying OffChainAssetValuatorProxy...');
    const initialCollateralValue = new BN('8557754000000000000000000');
    offChainAssetValuator = await deployContract(OffChainAssetValuatorProxy, [implementation.address, deployer, guardian, guardian, link.address, _0_1, initialCollateralValue, chainlinkJobId], deployer, 4e6);
    offChainAssetValuator = loader.truffle.fromArtifact('OffChainAssetValuatorImplV2', offChainAssetValuator.address);
  } else {
    offChainAssetValuator = loader.truffle.fromArtifact('OffChainAssetValuatorProxy', offChainAssetValuatorAddress);
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    offChainCurrencyValuator = loader.truffle.fromArtifact('OffChainCurrencyValuatorProxy', '0x105808e0F32cf9b51567CF2DFCE6403CA962FC0C');
  } else if (environment !== 'PRODUCTION' || offChainCurrencyValuatorAddress === null) {
    console.log('Deploying OffChainCurrencyValuatorImplV2...');
    const implementation = await deployContract(OffChainCurrencyValuatorImplV2, [], deployer, 4e6);
    console.log('Deploying OffChainCurrencyValuatorProxy...');
    offChainCurrencyValuator = await deployContract(OffChainCurrencyValuatorProxy, [implementation.address, deployer, guardian, guardian], deployer, 4e6);
    offChainCurrencyValuator = loader.truffle.fromArtifact('OffChainCurrencyValuatorImplV2', offChainCurrencyValuator.address);
  } else {
    offChainCurrencyValuator = loader.truffle.fromArtifact('OffChainCurrencyValuatorProxy', offChainCurrencyValuatorAddress);
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    underlyingTokenValuator = loader.truffle.fromArtifact('UnderlyingTokenValuatorProxy', '0xadeC704f3ce4498cAE4547F20152d58944aCd2D9');
  } else if (environment !== 'PRODUCTION' || underlyingTokenValuatorAddress === null) {
    console.log('Deploying UnderlyingTokenValuatorImplV5...');
    const implementation = await deployContract(UnderlyingTokenValuatorImplV5, [], deployer, 4e6);

    console.log('Deploying DAI-USD oracle...');
    const daiUsdAggregator = await deployContract(DaiUsdAggregatorMock, [], deployer, 4e6);

    console.log('Deploying ETH-USD oracle...');
    const ethUsdAggregator = await deployContract(EthUsdAggregatorMockV2, [], deployer, 4e6);

    console.log('Deploying USDC-ETH oracle...');
    const usdcEthAggregator = await deployContract(UsdcEthAggregatorMock, [], deployer, 4e6);

    console.log('Deploying UnderlyingTokenValuatorProxy... ');
    const tokens = [dai.address, usdc.address, weth.address];
    const aggregators = [daiUsdAggregator.address, ethUsdAggregator.address, usdcEthAggregator.address];
    const quoteSymbols = [constants.ZERO_ADDRESS, constants.ZERO_ADDRESS, weth.address];
    const params = [implementation.address, deployer, guardian, guardian, weth.address, tokens, aggregators, quoteSymbols];
    underlyingTokenValuator = await deployContract(UnderlyingTokenValuatorProxy, params, deployer, 4e6);
    underlyingTokenValuator = loader.truffle.fromArtifact('UnderlyingTokenValuatorImplV5', underlyingTokenValuator.address);
  } else {
    underlyingTokenValuator = loader.truffle.fromArtifact('UnderlyingTokenValuatorProxy', underlyingTokenValuatorAddress);
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    dmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory', '0x96Dcf92C4eFBec5Cd83f36944b729C146FBe13B6');
  } else if (environment !== 'PRODUCTION' || dmmEtherFactoryAddress === null) {
    console.log('Deploying DmmEtherFactory...');
    dmmEtherFactory = await deployContract(DmmEtherFactory, [weth.address], deployer, 6e6);
  } else {
    dmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory', dmmEtherFactoryAddress)
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    dmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory', '0x500cD65Bd10c00907ED2B9AC0282baC412A482e8');
  } else if (environment !== 'PRODUCTION' || dmmTokenFactoryAddress === null) {
    console.log('Deploying DmmTokenFactory...');
    dmmTokenFactory = await deployContract(DmmTokenFactory, [], deployer, 6e6);
  } else {
    dmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory', dmmTokenFactoryAddress);
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    dmmBlacklist = loader.truffle.fromArtifact('DmmBlacklistable', '0x048cb15f882feA832B7513ed1Bd0Ed66504d0343');
  } else if (environment !== 'PRODUCTION' || dmmBlacklistAddress === null) {
    console.log('Deploying DmmBlacklistable...');
    dmmBlacklist = await deployContract(DmmBlacklistable, [], deployer, 4e6);
    dmmBlacklist = loader.truffle.fromArtifact('DmmBlacklistable', dmmBlacklist.address);
  } else {
    dmmBlacklist = loader.truffle.fromArtifact('DmmBlacklistable', dmmBlacklistAddress);
  }

  // if ((environment === 'TESTNET' || environment === 'PRODUCTION')) {
  //   const _9 = _1.mul(new BN('9'));
  //   if((await link.balanceOf(deployer)).gte(_9)) {
  //     console.log('Sending 9 LINK to collateral valuator');
  //     await callContract(link, 'transfer', [offChainAssetValuator.address, _9], deployer, 3e5);
  //   }
  //
  //   if (oracleAddress !== '0x0000000000000000000000000000000000000000' && chainlinkJobId !== '0x0000000000000000000000000000000000000000000000000000000000000000') {
  //     console.log('Sending chainlinkRequest using oracle ', oracleAddress);
  //     await callContract(
  //       offChainAssetValuator,
  //       'submitGetOffChainAssetsValueRequest',
  //       [oracleAddress],
  //       deployer,
  //       1e6,
  //     );
  //   } else {
  //     console.log('Skipping chainlinkRequest because oracle address or job ID is not set', oracleAddress);
  //   }
  // }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    dmmController = loader.truffle.fromArtifact('DmmController', '0x5Ac111AeD2B53F2b43B60d5f4729CF1076d48391');
    dmmController.methods = dmmController.contract.methods;
  } else if (environment !== 'PRODUCTION' || dmmControllerAddress === null) {
    console.log('Deploying DmmController...');
    dmmController = await deployContract(
      DmmController,
      [
        guardian,
        interestRateImpl.address,
        offChainAssetValuator.address,
        offChainCurrencyValuator.address,
        underlyingTokenValuator.address,
        dmmEtherFactory.address,
        dmmTokenFactory.address,
        dmmBlacklist.address,
        /* minCollateralization */ _1,
        /* minReserveRatio */ _0_5,
        weth.address,
      ],
      deployer,
      5e6,
    );
    dmmController = loader.truffle.fromArtifact('DmmController', dmmController.address);
    dmmController.methods = dmmController.contract.methods;
  } else {
    dmmController = loader.truffle.fromArtifact('DmmController', dmmControllerAddress);
    dmmController.methods = dmmController.contract.methods;
  }

  await addMarketsIfLocal(environment, deployer);

  console.log('InterestRateImplV1: ', interestRateImpl.address);
  console.log('OffChainAssetValuatorProxy: ', offChainAssetValuator.address);
  console.log('OffChainCurrencyValuatorProxy: ', offChainCurrencyValuator.address);
  console.log('UnderlyingTokenValuatorProxy: ', underlyingTokenValuator.address);
  console.log('DmmEtherFactory: ', dmmEtherFactory.address);
  console.log('DmmTokenFactory: ', dmmTokenFactory.address);
  console.log('DmmBlacklistable: ', dmmBlacklist.address);
  console.log('DmmController: ', dmmController.address);
};

const addMarketsIfLocal = async (environment, deployer) => {
  if (environment !== 'LOCAL' && process.env.ADD_MARKETS !== 'true') {
    console.log('Skipping addition of markets')
    return;
  }

  await callContract(dmmTokenFactory, 'transferOwnership', [dmmController.address], deployer, 3e5);
  await callContract(dmmEtherFactory, 'transferOwnership', [dmmController.address], deployer, 3e5);

  await callContract(
    dmmController,
    'addMarket',
    [
      dai.address,
      'mDAI',
      'DMM: DAI',
      18,
      _0_01,
      _0_01,
      _1.mul(new BN(10000000)),
    ],
    deployer,
    6e6,
  );

  await callContract(
    dmmController,
    'addMarket',
    [
      weth.address,
      'mETH',
      'DMM: ETH',
      18,
      _0_01,
      _0_01,
      _1.mul(new BN(25000)),
    ],
    deployer,
    6e6,
  );

  await callContract(
    dmmController,
    'addMarket',
    [
      usdc.address,
      'mUSDC',
      'DMM: USDC',
      6,
      new BN('10000'),
      new BN('10000'),
      new BN('10000000000000'),
    ],
    deployer,
    6e6,
  );
};

module.exports = {
  interestRateImpl,
  offChainAssetValuator,
  offChainCurrencyValuator,
  underlyingTokenValuator,
  dmmTokenFactory,
  dmmBlacklist,
  dmmController,
  deployEcosystem,
};