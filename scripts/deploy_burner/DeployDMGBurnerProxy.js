const {throwError} = require('../GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No PROVIDER specified!');
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 115e9;

exports.defaultGasPrice = defaultGasPrice;
exports.web3 = web3;

const dmgBurnerV1 = '0x9dB8044e2cca314b9E7d164A380C1C64b1107633';
const uniswapV2Router = '0x7a250d5630b4cf539739df2c5dacb4c659f2488d';
const safeAddress = '0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF';
const dmgToken = '0xEd91879919B71bB6905f23af0A68d231EcF87b14';

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
    dmgBurnerV1,
    safeAddress,
    uniswapV2Router,
    dmgToken,
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