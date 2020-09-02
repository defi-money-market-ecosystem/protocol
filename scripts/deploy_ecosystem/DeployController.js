const {throwError} = require('../GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No PROVIDER specified!');
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {BN} = require('ethereumjs-util');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 77e9;

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

  let multiSigWallet;
  if (environment === 'LOCAL') {
    multiSigWallet = deployer;
  } else if (environment === 'TESTNET') {
    multiSigWallet = "0x0323cE501DD42Ed46a409D86e4EB6a9745FCA9EC";
  } else if (environment === 'PRODUCTION') {
    multiSigWallet = "0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF";
  } else {
    throw new Error("Invalid environment, found: " + environment);
  }

  const loader = setupLoader({provider: web3, defaultSender: deployer, defaultGasPrice: 8e9});
  const params = [
    multiSigWallet,                               // guardian
    '0x6f2a3b2efa07d264ea79ce0b96d3173a8feacd35', // interestRateInterface
    '0xace9112efe78d9e5018fd12164d30366ca629ab4', // offChainAssetsValuator
    '0x35cceb6ed6eb90d0c89a8f8b28e00ae23545312b', // offChainCurrencyValuator
    '0x0c65c147aaf2dbd5109ba74e36f730d081489b5b', // underlyingTokenValuator
    '0x1186d7dff910aa6c74bb9af71539c668133034ac', // DMM Ether Factory
    '0x6Ce6C84Fe43Df6A28c209b36179bD84a52CAEEFe', // DMM Token Factory
    '0x516d652e2f12876f5f0244aa661b1c262a2d96b1', // DMM Blacklistable
    '1000000000000000000',                        // Min Collateralization
    '500000000000000000',                         // Min Reserve Ratio
    '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2', // WETH
  ]

  const DmmController = loader.truffle.fromArtifact('DmmController');
  await deployContract(
    DmmController,
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