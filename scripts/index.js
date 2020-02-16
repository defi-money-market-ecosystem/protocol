const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : new Error('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');

const {deployEcosystem} = require('./DeployEcosystem');
const {deployLibraries} = require('./DeployLibrary');
const {deployOwnershipChanges} = require('./TransferOwnership');
const {deployTimeDelay} = require('./DeployTimeDelay');
const {deployTokens} = require('./DeployTokens');

const web3 = new Web3(provider);

const main = async () => {
  let deployer;
  if (process.env.DEPLOYER) {
    const account = web3.eth.accounts.privateKeyToAccount('0x' + privateKey);
    web3.eth.accounts.wallet.add(account);
    web3.eth.defaultAccount = account.address;
    deployer = account.address;
  } else {
    deployer = (await web3.eth.getAccounts())[0];
  }

  let multiSigWallet;
  if (environment === 'LOCAL') {
    multiSigWallet = deployer;
  } else if (environment === 'TESTNET') {
    multiSigWallet = ""; // TODO
  } else if (environment === 'PRODUCTION') {
    multiSigWallet = ""; // TODO
  } else {
    new Error("Invalid environment, found: " + environment);
  }

  const loader = setupLoader({provider: web3, defaultSender: deployer, defaultGasPrice: 8e9});

  await deployTokens(loader, environment);
  await deployLibraries(loader, environment);
  await deployEcosystem(loader, environment);
  await deployTimeDelay(loader, environment);
  await deployOwnershipChanges(environment, multiSigWallet);
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