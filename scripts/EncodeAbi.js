const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {BN} = require('ethereumjs-util');
const {callContract, deployContract} = require('./ContractUtils');

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

  const wethAddress = "0x5AE1948b45D61917452Af4208e3b2Fef1bc70e12";

  const DelayedOwner = loader.truffle.fromArtifact('DelayedOwner');
  const DmmController = loader.truffle.fromArtifact('DmmController');
  const DmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory');
  const DmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory');
  const DmmToken = loader.truffle.fromArtifact('DmmToken');

  const delayedOwner = await DelayedOwner.at("0xcfD027019F9Ff28AC3db417b630c7a21881090fb");
  const dmmController = await DmmController.at("0x1A902f45a2d54a8c0fc59B3C8552A03D74aaEF03");

  // const params = [
  //   '0x7a01313ED513F13ACc35536Cb66FEb5362e6C3C3',
  //   '0x681Ba299ee5619DC96f5d87aE0F5B19EAB3Cbe8A',
  //   '0xccA971a0d728f138C96a0E14b20040832EA55053',
  //   '',
  //   '',
  //   '0xbB2706d18b5Def6F66b1f97ee47b42eA6A45F73a',
  //   '100000000000000000', // 10% or 0.10,
  //   '500000000000000000', // 50%
  //   '0x5AE1948b45D61917452Af4208e3b2Fef1bc70e12',
  // ];
  // const dmmController = await deployContract(DmmController, params, deployer, 6e6, web3, 1e9);
  // await callContract(dmmController, 'transferOwnership', ['0xcfD027019F9Ff28AC3db417b630c7a21881090fb'], deployer, 1e6, undefined, web3, 1e9);
  // await callContract(dmmEtherFactory, 'transferOwnership', [dmmController.address], deployer, 1e6, undefined, web3, 1e9);
  // await callContract(dmmTokenFactory, 'transferOwnership', [dmmController.address], deployer, 1e6, undefined, web3, 1e9);

  // const innerAbi = dmmController.contract.methods.addMarket(
  //   '0x298bB14DFB95bBb2aC0Fd5AD4644D6f80dCAd7c7',
  //   'DMM: DAI',
  //   'mDAI',
  //   18,
  //   '10000000000',
  //   '10000000000',
  //   '5000000000000000000000000',
  // ).encodeABI();
  // const innerAbi = dmmController.contract.methods.addMarket(
  //   '0xbA901EeC621E8a3d77cd2e43aB78Ce96528B4496',
  //   'DMM: USDC',
  //   'mUSDC',
  //   6,
  //   '1',
  //   '1',
  //   '5000000000000',
  // ).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    dmmController.address,
    innerAbi,
  ).encodeABI();

  // const actualAbi = delayedOwner.contract.methods.executeTransaction(
  //   0,
  // ).encodeABI();

  console.log("actualAbi ", actualAbi);
};

main().catch(error => {
  console.error("Error ", error);
});