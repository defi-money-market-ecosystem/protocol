const {throwError} = require('../GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No PROVIDER specified!');
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {BN} = require('ethereumjs-util');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 225e9;

exports.defaultGasPrice = defaultGasPrice;
exports.web3 = web3;

const yieldFarmingV1 = '0x059afb3b37a66868804ecf1a4a14eaa2be548880';
const safeAddress = '0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF';
const dmmController = '0xB07EB3426d742cda9120931e7028d54F9dF34A3e';
const dmgToken = '0xEd91879919B71bB6905f23af0A68d231EcF87b14';
const dmgGrowthCoefficient = '1';

const mDAIPool = '0x8dA81AfEA7986698772a611bF37501236d443528';
const mUSDCPool = '0x78Bda7a14d31C5C845E0b8E9E9E4B119E7691723';
const mUSDTPool = '0xf2482f09f54125a3659f788cf7436af0753d969f';
const mWETHPool = '0xa896f041a2b18e58e7fbc513cd371de1348596de';
const allowableTokens = [mDAIPool, mUSDCPool, mUSDTPool, mWETHPool];

const dai = '0x6b175474e89094c44da98b954eedeac495271d0f';
const usdc = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
const usdt = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
const weth = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
const underlyingTokens = [dai, usdc, usdt, weth];

const tokenDecimals = [18, 6, 6, 18];
const points = ['200', '200', '200', '100'];

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
  const params = [
    yieldFarmingV1,
    safeAddress,
    dmgToken,
    safeAddress,
    dmmController,
    dmgGrowthCoefficient,
    allowableTokens,
    underlyingTokens,
    tokenDecimals,
    points,
  ];

  const DMGYieldFarmingProxy = loader.truffle.fromArtifact('DMGYieldFarmingProxy');
  await deployContract(
    DMGYieldFarmingProxy,
    params,
    deployer,
    5e6,
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