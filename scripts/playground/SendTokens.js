const provider = process.env.PROVIDER ? process.env.PROVIDER : new Error('No PROVIDER specified!');
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {BN} = require('ethereumjs-util');
const {callContract} = require('../ContractUtils');

const loader = setupLoader({provider: provider, defaultGasPrice: 8e9});
const web3 = new Web3(provider);

const _5e18 = new BN('5000000000000000000');
const _100000_e18 = new BN('100000000000000000000000');
const _2e6 = new BN('2000000');
const _100000_e6 = new BN('100000000000');

const DmmToken = loader.truffle.fromArtifact('DmmToken');
const ERC20 = loader.truffle.fromArtifact('ERC20');
const ERC20Mock = loader.truffle.fromArtifact('ERC20Mock');
const WETHMock = loader.truffle.fromArtifact('WETHMock');

const main = async () => {
  const privateKey = process.env.DEPLOYER;
  const account = web3.eth.accounts.privateKeyToAccount('0x' + privateKey);
  web3.eth.accounts.wallet.add(account);
  web3.eth.defaultAccount = account.address;
  const deployer = account.address;

  // const dai = await ERC20Mock.at('0xf15a6519b099A8eb7ffA9f12AF0D878B0f85a918');
  // const mDAI = await DmmToken.at('0xC1d81D71b703f387A82510615b367928BD74C819');
  // await callContract(dai, 'setBalance', [mDAI.address, _100000_e18], deployer, 3e5, 0, web3, 3e9);
  //
  // const usdc = await ERC20Mock.at('0x54db15edFb7552f0314e89966afa6C89ff157386');
  // const mUSDC = await DmmToken.at('0x402f9c5Dadb4D9E5cbf74A99693A379F875dBc25');
  // await callContract(usdc, 'setBalance', [mUSDC.address, _100000_e6], deployer, 3e5, 0, web3, 3e9);

  const usdcCircle = await ERC20.at('0x07865c6E87B9F70255377e024ace6630C1Eaa37F');
  const mUSDC_Circle = await DmmToken.at('0xC4Ff4B501e92792Aa5F048788447394858C32B3F');
  await callContract(usdcCircle, 'transfer', [mUSDC_Circle.address, _2e6], deployer, 3e5, 0, web3, 3e9);

  // const weth = await WETHMock.at('0x893178fBD1b3eb77cB85Ab39Bb3b3EDF2609a478');
  // await callContract(weth, 'deposit', [], deployer, 3e5, _5e18, web3, 3e9);
  // const mETH = await DmmToken.at('0xF3516dC84E0322542320690818E292aBCCD954f2');
  // await callContract(weth, 'transfer', [mETH.address, _5e18], deployer, 3e5, 0, web3, 3e9);
};

main()
  .then(() => {
    console.log("Finished successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Could not call function due to error: ", error);
    process.exit(-1);
  });