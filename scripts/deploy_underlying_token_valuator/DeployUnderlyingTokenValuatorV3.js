const {linkContract} = require('../ContractUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : new Error('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {callContract, deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 8e9;

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

  const delayedOwner = loader.truffle.fromArtifact('DelayedOwner', '0x9E97Ee8631dA9e96bC36a6bF39d332C38d9834DD');
  delayedOwner.methods = delayedOwner.contract.methods;

  const daiAddress = '0x6b175474e89094c44da98b954eedeac495271d0f';
  const usdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
  const wethAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
  const daiUsdAggregatorAddress = '0xa7D38FBD325a6467894A13EeFD977aFE558bC1f0';
  const ethUsdAggregatorAddress = '0x79fEbF6B9F76853EDBcBc913e6aAE8232cFB9De9';
  const usdcEthAggregatorAddress = '0xdE54467873c3BCAA76421061036053e371721708';

  const UnderlyingTokenValuatorImplV3 = loader.truffle.fromArtifact('UnderlyingTokenValuatorImplV3');
  await UnderlyingTokenValuatorImplV3.detectNetwork();
  await linkContract(UnderlyingTokenValuatorImplV3, 'StringHelpers', '0x50adD802Bbe45d06ac5d52bF3CDAC40f8648cf95');

  const underlyingTokenValuatorImplV3 = await deployContract(
    UnderlyingTokenValuatorImplV3,
    [daiAddress, usdcAddress, wethAddress, daiUsdAggregatorAddress, ethUsdAggregatorAddress, usdcEthAggregatorAddress],
    deployer,
    1.5e6,
    web3,
    defaultGasPrice,
  );
  await callContract(
    underlyingTokenValuatorImplV3,
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