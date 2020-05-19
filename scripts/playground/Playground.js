const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {BN} = require('ethereumjs-util');
const {callContract, deployContract} = require('../ContractUtils');

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

  const DmmController = loader.truffle.fromArtifact('DmmController');
  const dmmController = await DmmController.at('0x5Ac111AeD2B53F2b43B60d5f4729CF1076d48391');
  const innerAbi = dmmController.contract.methods.addMarket(
    '0x07865c6e87b9f70255377e024ace6630c1eaa37f',
    'mUSDC',
    'DMM: USDC (Circle)',
    6,
    new BN('10000').toString(10),
    new BN('10000').toString(10),
    new BN('1000000000000').toString(10),
  ).encodeABI()

  const DelayedOwner = loader.truffle.fromArtifact('DelayedOwner');
  const delayedOwner = await DelayedOwner.at('0x6C8C010354A010bee5E8b563eC457614B9Db8eFf')

  await callContract(
    delayedOwner,
    'transact',
    [dmmController.address, innerAbi],
    deployer,
    6e6,
    0,
    web3,
    3e9,
  );
};

main()
  .then(() => console.log('Finished calling main'))
  .catch(error => console.error('Failed to call main due to error ', error));