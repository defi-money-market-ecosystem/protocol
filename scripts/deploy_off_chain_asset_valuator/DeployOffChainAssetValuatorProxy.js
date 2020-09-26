const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : new Error('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {callContract, deployContract} = require('../ContractUtils');
const {BN} = require('ethereumjs-util');

const web3 = new Web3(provider);
const defaultGasPrice = 100e9;

const implementationAddress = '0xf31D3f919A0b986D3655Fd6c1Cfda2edF2dAcCB5';
const governorAddress = '0xE679eBf544A6BE5Cb8747012Ea6B08F04975D264';

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

  const linkAddress = '0x514910771af9ca656af840dff83e8264ecf986ca';
  const _0_5 = new BN('500000000000000000');
  const initialCollateralValue = new BN('8792879000000000000000000');
  const chainlinkJobId = '0x2017ac2b3b5b37d2fbb5fef6193d6eef0cb50a4c6b3796c5b5c44bd1cca83aa0';

  const OffChainAssetValuatorProxy = loader.truffle.fromArtifact('OffChainAssetValuatorProxy');
  const params = [implementationAddress, multiSigWallet, governorAddress, multiSigWallet, linkAddress, _0_5, initialCollateralValue, chainlinkJobId];
  await deployContract(OffChainAssetValuatorProxy, params, deployer, 2e6, web3, defaultGasPrice);
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