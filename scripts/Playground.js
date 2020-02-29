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

  const linkAddress = '0x01BE23585060835E02B77ef475b0Cc51aA1e0709';
  const link = await loader.truffle.fromArtifact('IERC20').at(linkAddress);

  const payment = '100000000000000000';
  const oracleAddress = '0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e';
  const chainlinkJobId = '0xd4b380b30cb64722b8843ead232985c300000000000000000000000000000000';

  console.log("Deploying contract...");
  const OffChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1');
  const OffChainAssetValuatorImplV1 = await deployContract(OffChainAssetValuatorImplV1, [linkAddress, payment, chainlinkJobId], deployer, 4e6, web3, 1e9);

  console.log("Sending 10 LINK to collateral valuator");
  const _10 = new BN('10000000000000000000');
  await callContract(link, 'transfer', [OffChainAssetValuatorImplV1.address, _10], deployer, 3e5, 0, web3, 1e9);

  await callContract(OffChainAssetValuatorImplV1, 'getOffChainAssetsValue', [oracleAddress], deployer, 1e6, 0, web3, 1e9);
};

main();