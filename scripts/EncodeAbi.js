const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {BN} = require('ethereumjs-util');

const loader = setupLoader({provider: provider, defaultGasPrice: 8e9});

const web3 = new Web3(provider);
const defaultGasPrice = 8e9;

exports.defaultGasPrice = defaultGasPrice;
exports.web3 = web3;

const main = async () => {
  const privateKey = process.env.DEPLOYER;
  const account = web3.eth.accounts.privateKeyToAccount('0x' + privateKey);
  web3.eth.accounts.wallet.add(account);
  web3.eth.defaultAccount = account.address;
  const deployer = account.address;

  const DelayedOwner = loader.truffle.fromArtifact('DelayedOwner');
  const DmmController = loader.truffle.fromArtifact('DmmController');

  const delayedOwner = await DelayedOwner.at("0xcfD027019F9Ff28AC3db417b630c7a21881090fb");
  const dmmController = await DmmController.at("0x02ee9AEbb75470D517BFf722D36762d2b231539C");

  // const innerAbi = dmmController.contract.methods.setCollateralValuator(
  //   "0x681Ba299ee5619DC96f5d87aE0F5B19EAB3Cbe8A"
  // ).encodeABI();
  //
  // const actualAbi = delayedOwner.contract.methods.transact(
  //   "0x02ee9AEbb75470D517BFf722D36762d2b231539C",
  //   innerAbi,
  // ).encodeABI();

  const actualAbi = delayedOwner.contract.methods.executeTransaction(
    0,
  ).encodeABI();

  console.log("actualAbi ", actualAbi);
};

main().catch(error => {
  console.error("Error ", error);
});