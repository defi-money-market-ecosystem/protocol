// const {dai, link, usdc, weth} = require('./DeployTokens');
const {BN} = require('ethereumjs-util');

let interestRateImplV1 = null;
let chainlinkCollateralValuator = null;
let underlyingTokenValuatorImplV1 = null;
let dmmEtherFactory = null;
let dmmTokenFactory = null;
let dmmBlacklist = null;
let dmmController = null;

const _0_1 = new BN('100000000000000000'); // 0.1
const _05 = new BN('500000000000000000'); // 0.5
const _1 = new BN('1000000000000000000'); // 1.0

const deployEcosystem = async (loader, environment) => {
  const ChainlinkCollateralValuator = loader.truffle.fromArtifact('ChainlinkCollateralValuator');
  const DmmBlacklistable = loader.truffle.fromArtifact('DmmBlacklistable');
  const InterestRateImplV1 = loader.truffle.fromArtifact('InterestRateImplV1');
  const DmmController = loader.truffle.fromArtifact('DmmController');
  const DmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory');
  const DmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory');
  const UnderlyingTokenValuatorImplV1 = loader.truffle.fromArtifact('UnderlyingTokenValuatorImplV1');

  let oracleAddress;
  let chainlinkJobId;

  if (environment === 'LOCAL') {
    oracleAddress = '0x0000000000000000000000000000000000000000';
    chainlinkJobId = '0x0000000000000000000000000000000000000000000000000000000000000000';
  } else if (environment === 'TESTNET') {
    oracleAddress = '0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e';
    chainlinkJobId = '0x00000000000000000000000000000000d4b380b30cb64722b8843ead232985c3';
  } else if (environment === 'PRODUCTION') {
    oracleAddress = '0x0000000000000000000000000000000000000000';
    chainlinkJobId = '0x0000000000000000000000000000000000000000000000000000000000000000';
  } else {
    new Error('Invalid environment, found ' + environment);
  }

  await DmmEtherFactory.detectNetwork();
  await DmmTokenFactory.detectNetwork();
  await UnderlyingTokenValuatorImplV1.detectNetwork();

  await DmmEtherFactory.link('DmmTokenLibrary', dmmTokenLibrary.address);
  await DmmTokenFactory.link('DmmTokenLibrary', dmmTokenLibrary.address);
  await UnderlyingTokenValuatorImplV1.link('StringHelpers', stringHelpers.address);

  interestRateImplV1 = await InterestRateImplV1.new();
  chainlinkCollateralValuator = await ChainlinkCollateralValuator.new(link.address, _0_1, chainlinkJobId, {gas: 6e6});
  underlyingTokenValuatorImplV1 = await UnderlyingTokenValuatorImplV1.new(dai.address, usdc.address, {gas: 6e6});
  dmmEtherFactory = await DmmEtherFactory.new(weth.address, {gas: 6e6});
  dmmTokenFactory = await DmmTokenFactory.new({gas: 6e6});
  dmmBlacklist = await DmmBlacklistable.new({gas: 6e6});

  await chainlinkCollateralValuator.getCollateralValue(oracleAddress);

  dmmController = await DmmController.new(
    interestRateImplV1.address,
    chainlinkCollateralValuator.address,
    underlyingTokenValuatorImplV1.address,
    dmmEtherFactory.address,
    dmmTokenFactory.address,
    dmmBlacklist.address,
    /* minCollateralization */ _1,
    /* minReserveRatio */ _05,
    weth.address,
    {gas: 6e6}
  );

  console.log('InterestRateImplV1: ', interestRateImplV1.address);
  console.log('ChainlinkCollateralValuator: ', chainlinkCollateralValuator.address);
  console.log('UnderlyingTokenValuatorImplV1: ', underlyingTokenValuatorImplV1.address);
  console.log('DmmTokenFactory: ', dmmTokenFactory.address);
  console.log('DmmBlacklistable: ', dmmBlacklist.address);
  console.log('DmmController: ', dmmController.address);
};

module.exports = {
  interestRateImplV1,
  chainlinkCollateralValuator,
  underlyingTokenValuatorImplV1,
  dmmTokenFactory,
  dmmBlacklist,
  dmmController,
  deployEcosystem,
};