const {linkContract} = require('../ContractUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : new Error('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {callContract, deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 50e9;

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

  const loader = setupLoader({provider: web3, defaultSender: deployer, defaultGasPrice: 8e9});

  const delayedOwner = loader.truffle.fromArtifact('DelayedOwner', '0x9E97Ee8631dA9e96bC36a6bF39d332C38d9834DD');
  delayedOwner.methods = delayedOwner.contract.methods;

  const daiAddress = '0x6b175474e89094c44da98b954eedeac495271d0f';
  const usdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
  const usdtAddress = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
  const wethAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
  const daiUsdAggregatorAddress = '0xa7D38FBD325a6467894A13EeFD977aFE558bC1f0';
  const ethUsdAggregatorAddress = '0xF79D6aFBb6dA890132F9D7c355e3015f15F3406F';
  const usdcEthAggregatorAddress = '0xdE54467873c3BCAA76421061036053e371721708';
  const usdtEthAggregatorAddress = '0xa874fe207DF445ff19E7482C746C4D3fD0CB9AcE';

  const UnderlyingTokenValuatorImplV4 = loader.truffle.fromArtifact('UnderlyingTokenValuatorImplV4');
  await UnderlyingTokenValuatorImplV4.detectNetwork();
  await linkContract(UnderlyingTokenValuatorImplV4, 'StringHelpers', '0x50adD802Bbe45d06ac5d52bF3CDAC40f8648cf95');

  const underlyingTokenValuatorImplV4 = await deployContract(
    UnderlyingTokenValuatorImplV4,
    [daiAddress, usdcAddress, usdtAddress, wethAddress, daiUsdAggregatorAddress, ethUsdAggregatorAddress, usdcEthAggregatorAddress, usdtEthAggregatorAddress],
    deployer,
    2e6,
    web3,
    defaultGasPrice,
  );
  await callContract(
    underlyingTokenValuatorImplV4,
    'transferOwnership',
    [delayedOwner.address],
    deployer,
    4e5,
    0,
    web3,
    defaultGasPrice,
  )
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