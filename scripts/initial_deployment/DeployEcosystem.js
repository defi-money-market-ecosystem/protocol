// const {dai, link, usdc, weth} = require('./DeployTokens');
const {BN} = require('ethereumjs-util');
const {callContract, deployContract, linkContract} = require('../ContractUtils');

global.interestRateImplV1 = null;
global.offChainAssetValuatorImplV1 = null;
global.offChainCurrencyValuatorImplV1 = null;
global.underlyingTokenValuatorImplV3 = null;
global.delayedOwner = null;
global.dmmEtherFactory = null;
global.dmmTokenFactory = null;
global.dmmBlacklist = null;
global.dmmController = null;

const _0_1 = new BN('100000000000000000'); // 0.1
const _0_01 = new BN('10000000000000000'); // 0.01
const _0_5 = new BN('500000000000000000'); // 0.5
const _1 = new BN('1000000000000000000'); // 1.0

const deployEcosystem = async (loader, environment, deployer) => {
  const OffChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1');
  const DmmBlacklistable = loader.truffle.fromArtifact('DmmBlacklistable');
  const DmmController = loader.truffle.fromArtifact('DmmController');
  const DmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory');
  const DmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory');
  const InterestRateImplV1 = loader.truffle.fromArtifact('InterestRateImplV1');
  const OffChainCurrencyValuatorImplV1 = loader.truffle.fromArtifact('OffChainCurrencyValuatorImplV1');
  const UnderlyingTokenValuatorImplV3 = loader.truffle.fromArtifact('UnderlyingTokenValuatorImplV3');

  const DaiUsdAggregatorMock = loader.truffle.fromArtifact('DaiUsdAggregatorMock');
  const EthUsdAggregatorMockV2 = loader.truffle.fromArtifact('EthUsdAggregatorMockV2');
  const UsdcEthAggregatorMock = loader.truffle.fromArtifact('UsdcEthAggregatorMock');

  interestRateImplV1Address = '0x6F2A3b2EFa07D264EA79Ce0b96d3173a8feAcD35';
  offChainAssetValuatorImplV1Address = '0xAcE9112EfE78D9E5018fd12164D30366cA629Ab4';
  offChainCurrencyValuatorImplV1Address = '0x35cceb6ED6EB90d0c89a8F8b28E00aE23545312b';
  underlyingTokenValuatorImplV3Address = '0x7812e0F5Da2F0917BD9054951415EDFF571964dB';
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
    chainlinkJobId = '0x11cdfd87ac17f6fc2aea9ca5c77544f33decb571339a31f546c2b6a36a406f15';
  } else {
    new Error('Invalid environment, found ' + environment);
  }

  await DmmEtherFactory.detectNetwork();
  await DmmTokenFactory.detectNetwork();
  await UnderlyingTokenValuatorImplV3.detectNetwork();

  await DmmEtherFactory.link('DmmTokenLibrary', dmmTokenLibrary.address);
  await DmmTokenFactory.link('DmmTokenLibrary', dmmTokenLibrary.address);

  linkContract(UnderlyingTokenValuatorImplV3, 'StringHelpers', stringHelpers.address);

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    interestRateImplV1 = loader.truffle.fromArtifact('InterestRateImplV1', '0x32Df47aB270a1ec1450fA4b7abdFa94eE6b5F2fA');
  } else if (environment !== 'PRODUCTION' && interestRateImplV1Address !== null) {
    console.log('Deploying InterestRateImplV1...');
    interestRateImplV1 = await deployContract(InterestRateImplV1, [], deployer, 4e6);
  } else {
    interestRateImplV1 = loader.truffle.fromArtifact('InterestRateImplV1', interestRateImplV1Address);
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    offChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1', '0x4F665bE185C3Ce125A7c81B2C6b26Be6fd58C780')
  } else if (environment !== 'PRODUCTION' || offChainAssetValuatorImplV1Address === null) {
    console.log('Deploying OffChainAssetValuatorImplV1...');
    const initialCollateralValue = new BN('8557754000000000000000000');
    offChainAssetValuatorImplV1 = await deployContract(OffChainAssetValuatorImplV1, [link.address, _0_1, initialCollateralValue, chainlinkJobId], deployer, 4e6);
  } else {
    offChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1', offChainAssetValuatorImplV1Address)
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    offChainCurrencyValuatorImplV1 = loader.truffle.fromArtifact('OffChainCurrencyValuatorImplV1', '0x105808e0F32cf9b51567CF2DFCE6403CA962FC0C');
  } else if (environment !== 'PRODUCTION' || offChainCurrencyValuatorImplV1Address === null) {
    console.log('Deploying OffChainCurrencyValuatorImplV1...');
    offChainCurrencyValuatorImplV1 = await deployContract(OffChainCurrencyValuatorImplV1, [], deployer, 4e6);
  } else {
    offChainCurrencyValuatorImplV1 = loader.truffle.fromArtifact('OffChainCurrencyValuatorImplV1', offChainCurrencyValuatorImplV1Address);
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    underlyingTokenValuatorImplV3 = loader.truffle.fromArtifact('UnderlyingTokenValuatorImplV3', '0xadeC704f3ce4498cAE4547F20152d58944aCd2D9');
  } else if (environment !== 'PRODUCTION' || underlyingTokenValuatorImplV3Address === null) {
    const daiUsdAggregator = await deployContract(DaiUsdAggregatorMock, [], deployer, 4e6);
    const ethUsdAggregator = await deployContract(EthUsdAggregatorMockV2, [], deployer, 4e6);
    const usdcEthAggregator = await deployContract(UsdcEthAggregatorMock, [], deployer, 4e6);
    console.log('Deploying UnderlyingTokenValuatorImplV3... ');
    const params = [dai.address, usdc.address, weth.address, daiUsdAggregator.address, ethUsdAggregator.address, usdcEthAggregator.address];
    underlyingTokenValuatorImplV3 = await deployContract(UnderlyingTokenValuatorImplV3, params, deployer, 4e6);
  } else {
    underlyingTokenValuatorImplV3 = loader.truffle.fromArtifact('UnderlyingTokenValuatorImplV3', underlyingTokenValuatorImplV3Address);
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
  } else {
    dmmBlacklist = loader.truffle.fromArtifact('DmmBlacklistable', dmmBlacklistAddress);
  }

  // if ((environment === 'TESTNET' || environment === 'PRODUCTION')) {
  //   const _9 = _1.mul(new BN('9'));
  //   if((await link.balanceOf(deployer)).gte(_9)) {
  //     console.log('Sending 9 LINK to collateral valuator');
  //     await callContract(link, 'transfer', [offChainAssetValuatorImplV1.address, _9], deployer, 3e5);
  //   }
  //
  //   if (oracleAddress !== '0x0000000000000000000000000000000000000000' && chainlinkJobId !== '0x0000000000000000000000000000000000000000000000000000000000000000') {
  //     console.log('Sending chainlinkRequest using oracle ', oracleAddress);
  //     await callContract(
  //       offChainAssetValuatorImplV1,
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
        interestRateImplV1.address,
        offChainAssetValuatorImplV1.address,
        offChainCurrencyValuatorImplV1.address,
        underlyingTokenValuatorImplV3.address,
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
  } else {
    dmmController = loader.truffle.fromArtifact('DmmController', dmmControllerAddress);
    dmmController.methods = dmmController.contract.methods;
  }

  await addMarketsIfLocal(environment, deployer);

  console.log('InterestRateImplV1: ', interestRateImplV1.address);
  console.log('OffChainAssetValuatorImplV1: ', offChainAssetValuatorImplV1.address);
  console.log('OffChainCurrencyValuatorImplV1: ', offChainCurrencyValuatorImplV1.address);
  console.log('UnderlyingTokenValuatorImplV3: ', underlyingTokenValuatorImplV3.address);
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
  interestRateImplV1,
  offChainAssetValuatorImplV1,
  offChainCurrencyValuatorImplV1,
  underlyingTokenValuatorImplV3,
  dmmTokenFactory,
  dmmBlacklist,
  dmmController,
  deployEcosystem,
};