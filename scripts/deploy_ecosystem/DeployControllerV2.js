const {throwError} = require('../GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No PROVIDER specified!');
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {BN} = require('ethereumjs-util');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 64e9;

exports.defaultGasPrice = defaultGasPrice;
exports.web3 = web3;

const main = async () => {
  let deployer;
  if (process.env.DEPLOYER) {
    const privateKey = process.env.DEPLOYER;
    const account = web3.eth.accounts.privateKeyToAccount('0x' + privateKey);
    web3.eth.accounts.wallet.add(account);
    web3.eth.defaultAccount = account.address;
    deployer = account.address;
  } else {
    throw Error("Invalid deployer, found nothing");
  }

  let guardian;
  if (environment === 'LOCAL') {
    guardian = deployer;
  } else if (environment === 'TESTNET') {
    guardian = "0x0323cE501DD42Ed46a409D86e4EB6a9745FCA9EC";
  } else if (environment === 'PRODUCTION') {
    guardian = "0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF";
  } else {
    throw new Error("Invalid environment, found: " + environment);
  }

  const loader = setupLoader({provider: web3, defaultSender: deployer, defaultGasPrice: 8e9});
  const params = [
    guardian,
    '0x22DA19b404F432D64e280c3c5712E52612b689Fd', // assetIntroducerProxy
    '0x7aB8CFF6bFFC83fBd4AC70BA7e00d454421eeA39', // collateralizationCalculator
    '0x6f2a3b2efa07d264ea79ce0b96d3173a8feacd35', // interestRateInterface
    '0x4F9c3332D352F1ef22F010ba93A9653261e1634b', // offChainAssetsValuator
    '0x826d758AF2FeD387ac15843327e143b2CAfE9047', // offChainCurrencyValuator
    '0xaC7e5e3b589D55a43D62b90c6b4C4ef28Ea35573', // underlyingTokenValuator
    '0x1186d7dff910aa6c74bb9af71539c668133034ac', // DMM Ether Factory
    '0x6Ce6C84Fe43Df6A28c209b36179bD84a52CAEEFe', // DMM Token Factory
    '0x516d652e2f12876f5f0244aa661b1c262a2d96b1', // DMM Blacklistable
    '1000000000000000000',                        // Min Collateralization
    '500000000000000000',                         // Min Reserve Ratio
    '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2', // WETH
  ]

  const DmmControllerV2 = loader.truffle.fromArtifact('DmmControllerV2');
  await deployContract(
    DmmControllerV2,
    params,
    deployer,
    5e6,
    web3,
    defaultGasPrice,
  );
};

main()
  .then(() => {
    console.log("Finished successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Could not deploy due to error: ", error);
    process.exit(-1);
  });