const {linkContract} = require('../ContractUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : new Error('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {callContract, deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 100e9;

exports.defaultGasPrice = defaultGasPrice;
exports.web3 = web3;
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

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

  const implementationAddress = '0x60847001648dFA648087FA1CA31152605Aa7822D';
  const governorTimelockAddress = '0xE679eBf544A6BE5Cb8747012Ea6B08F04975D264';
  const multisigWallet = '0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF';

  const daiAddress = '0x6b175474e89094c44da98b954eedeac495271d0f';
  const usdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
  const usdtAddress = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
  const wethAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
  const linkAddress = '0x514910771AF9Ca656af840dff83E8264EcF986CA';
  const dmgAddress = '0xEd91879919B71bB6905f23af0A68d231EcF87b14';

  const daiUsdAggregatorAddress = '0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9';
  const usdcEthAggregatorAddress = '0x986b5E1e1755e3C2440e960477f25201B0a8bbD4';
  const usdtEthAggregatorAddress = '0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46';
  const ethUsdAggregatorAddress = '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419';
  const linkUsdAggregatorAddress = '0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c';
  const dmgEthAggregatorAddress = '0xD010e899f7ab723AC93f825cDC5Aa057669557c2';

  const UnderlyingTokenValuatorProxy = loader.truffle.fromArtifact('UnderlyingTokenValuatorProxy');
  await UnderlyingTokenValuatorProxy.detectNetwork();
  await linkContract(UnderlyingTokenValuatorProxy, 'StringHelpers', '0x50adD802Bbe45d06ac5d52bF3CDAC40f8648cf95');

  const params = [
    implementationAddress,
    multisigWallet,
    governorTimelockAddress,
    multisigWallet,
    wethAddress,
    [daiAddress, usdcAddress, usdtAddress, wethAddress, linkAddress, dmgAddress],
    [daiUsdAggregatorAddress, usdcEthAggregatorAddress, usdtEthAggregatorAddress, ethUsdAggregatorAddress, linkUsdAggregatorAddress, dmgEthAggregatorAddress],
    [ZERO_ADDRESS, wethAddress, wethAddress, ZERO_ADDRESS, ZERO_ADDRESS, wethAddress],
  ];

  await deployContract(
    UnderlyingTokenValuatorProxy,
    params,
    deployer,
    2e6,
    web3,
    defaultGasPrice,
  );
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