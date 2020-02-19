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

  console.log("Owner, Pending Owner ", await delayedOwner.owner(), await delayedOwner.pendingOwner());

  // console.log(dmmController);
  const innerAbi = dmmController.contract.methods.addMarket(
    "0xbA901EeC621E8a3d77cd2e43aB78Ce96528B4496",
    "mUSDC",
    "DMM: USDC",
    6,
    "1",
    "1",
    "5000000000000", // 5m
  ).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    "0x02ee9AEbb75470D517BFf722D36762d2b231539C",
    innerAbi,
  ).encodeABI();

  console.log("actualAbi ", actualAbi);

  const realAbi = delayedOwner.contract.methods.claimOwnership().encodeABI();
  console.log("Real Owner ", realAbi);
};

main();