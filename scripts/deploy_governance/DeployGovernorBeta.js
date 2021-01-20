const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract} = require('../ContractUtils');
const {throwError} = require('../GeneralUtils');

const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No PROVIDER specified!');
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');

const web3 = new Web3(provider);
const defaultGasPrice = 55e9;

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

  const assetIntroducerProxy = '0x22DA19b404F432D64e280c3c5712E52612b689Fd';
  const dmg = '0xEd91879919B71bB6905f23af0A68d231EcF87b14';

  let guardian;
  if (environment === 'LOCAL') {
    guardian = deployer;
  } else if (environment === 'TESTNET') {
    guardian = "0x0323cE501DD42Ed46a409D86e4EB6a9745FCA9EC";
  } else if (environment === 'PRODUCTION') {
    guardian = "0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF";
  } else {
    throw new Error("Invalid environment, found: " + environment);
  }

  const loader = setupLoader({provider: web3, defaultSender: deployer, defaultGasPrice: 8e9});

  const GovernorBeta = loader.truffle.fromArtifact('GovernorBeta');
  const dmgToken = await deployContract(
    GovernorBeta,
    [assetIntroducerProxy, dmg, guardian],
    deployer,
    5e6,
    web3,
    defaultGasPrice,
  );
  const gasUsed = (await web3.eth.getTransactionReceipt(dmgToken.transactionHash)).gasUsed
  console.log(`Deployed DMG token with ${gasUsed} gas`)
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