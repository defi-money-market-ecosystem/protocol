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

  const UnderlyingTokenValuatorImplV5 = loader.truffle.fromArtifact('UnderlyingTokenValuatorImplV5');
  await UnderlyingTokenValuatorImplV5.detectNetwork();
  await linkContract(UnderlyingTokenValuatorImplV5, 'StringHelpers', '0x50adD802Bbe45d06ac5d52bF3CDAC40f8648cf95');

  await deployContract(
    UnderlyingTokenValuatorImplV5,
    [],
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