const {throwError} = require('../GeneralUtils');

const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No web3 PROVIDER specified');
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');

const {deployEcosystem} = require('./DeployEcosystem');
const {deployLibraries} = require('./DeployLibrary');
const {deployOwnershipChanges} = require('./TransferOwnership');
const {deployTimeDelay} = require('./DeployTimeDelay');
const {deployTokens} = require('./DeployTokens');

const web3 = new Web3(provider);
const defaultGasPrice = 15e9;

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
    guardian = process.env.GUARDIAN_ADDRESS;
  } else if (environment === 'PRODUCTION') {
    guardian = "0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF";
  } else {
    throw new Error("Invalid environment, found: " + environment);
  }

  if (!web3.utils.isAddress(guardian)) {
    throw Error(`Invalid guardian, expected an address but found ${guardian}`);
  }

  const loader = setupLoader({provider: web3, defaultSender: deployer, defaultGasPrice: 8e9});

  await deployTokens(loader, environment, deployer);
  await deployLibraries(loader, environment, deployer);
  await deployEcosystem(loader, environment, deployer, guardian);
  await deployTimeDelay(loader, environment, deployer);
  await deployOwnershipChanges(environment, deployer, guardian);
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