const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : new Error('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {callContract, deployContract} = require('../ContractUtils');
const {BN} = require('ethereumjs-util');

const web3 = new Web3(provider);
const defaultGasPrice = 5e9;

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

  delayedOwner = loader.truffle.fromArtifact('DelayedOwner', '0x9E97Ee8631dA9e96bC36a6bF39d332C38d9834DD');
  delayedOwner.methods = delayedOwner.contract.methods;

  const linkAddress = '0x514910771af9ca656af840dff83e8264ecf986ca';
  const _0_5 = new BN('500000000000000000');
  const initialCollateralValue = new BN('1000000000000000000');
  const chainlinkJobId = '0x11cdfd87ac17f6fc2aea9ca5c77544f33decb571339a31f546c2b6a36a406f15';

  const OffChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1');
  const offChainAssetValuatorImplV1 = await deployContract(OffChainAssetValuatorImplV1, [linkAddress, _0_5, initialCollateralValue, chainlinkJobId], deployer, 4e6, web3, defaultGasPrice);
  callContract(offChainAssetValuatorImplV1, 'transferOwnership', delayedOwner.address, deployer, 4e5, 0, web3, defaultGasPrice)
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