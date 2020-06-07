const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : new Error('No ENVIRONMENT specified!');
const vestingType = process.env.VESTING_TYPE
const Web3 = require('web3');
const {BN} = require('ethereumjs-util');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 24e9;

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

  const DMGTokenForwarder = loader.truffle.fromArtifact('DMGTokenForwarder');
  await deployContract(
    DMGTokenForwarder,
    [multiSigWallet],
    deployer,
    1e6,
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