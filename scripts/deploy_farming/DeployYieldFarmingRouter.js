const {throwError} = require('../GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No PROVIDER specified!');
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {BN} = require('ethereumjs-util');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 160e9;

exports.defaultGasPrice = defaultGasPrice;
exports.web3 = web3;

const dmgYieldFarmingProxy = '0x502e90e092Cd08e6630e8E1cE426fC6d8ADb3975';
const uniswapV2Factory = '0x5c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f';
const weth = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';

'000000000000000000000000502e90e092Cd08e6630e8E1cE426fC6d8ADb39750000000000000000000000005c69bee701ef814a2b6a3edd4b1652cb9cc5aa6f000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2'

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

  const DMGYieldFarmingRouter = loader.truffle.fromArtifact('DMGYieldFarmingRouter');
  await deployContract(
    DMGYieldFarmingRouter,
    [dmgYieldFarmingProxy, uniswapV2Factory, weth],
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