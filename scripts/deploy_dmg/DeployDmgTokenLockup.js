const {throwError} = require('../GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No PROVIDER specified!');
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');
const vestingType = process.env.VESTING_TYPE ? process.env.VESTING_TYPE : throwError('No VESTING_TYPE specified!');
const Web3 = require('web3');
const {BN} = require('ethereumjs-util');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract} = require('../ContractUtils');

const web3 = new Web3(provider);
const defaultGasPrice = 46e9;

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

  let params;
  if (vestingType === 'FUTURE_LONG_TERM') {
    params = getParamsForFutureVesting(multiSigWallet);
  } else if (vestingType === 'SIMPLE_SIX_MONTHS') {
    params = getParamsForSimple6MonthLockup(multiSigWallet);
  } else if (vestingType === 'NO_VESTING') {
    params = getParamsForNoLockup(multiSigWallet);
  } else if (vestingType === 'CUSTOM') {
    params = getParamsForCustomLockup()
  } else {
    throw new Error(`Invalid vesting type, found ${vestingType}`);
  }

  const DMGTokenLockup = loader.truffle.fromArtifact('DMGTokenLockup');
  await deployContract(
    DMGTokenLockup,
    params,
    deployer,
    1.2e6,
    web3,
    defaultGasPrice,
  );
};

function getParamsForFutureVesting(multiSigWallet) {
  return [
    multiSigWallet,
    new BN('1590451200'), // Starts on May 26, 2020
    new BN('14947200'), // 173 days as of May 26 to November 15, 2020
    new BN('46483200'), // 538 days as of May 26 to November 15, 2021
    false, // Tokens are un-revocable
  ];
}

function getParamsForSimple6MonthLockup(multiSigWallet) {
  return [
    multiSigWallet,
    new BN('1590451200'), // start timestamp - May 26, 2020
    new BN('14947200'), // 173 days as of May 26 to November 15, 2020
    new BN('14947200'), // vesting duration - same as cliff, which means vesting ends at cliff date.
    false, // Tokens are un-revocable from vesting
  ];
}

function getParamsForNoLockup(multiSigWallet) {
  return [
    multiSigWallet,
    new BN('1590451200'), // start timestamp - May 26, 2020
    new BN('0'), // cliff duration - nothing
    new BN('0'), // vesting duration - 5 months, in seconds
    false, // Tokens are un-revocable from vesting
  ];
}

function getParamsForCustomLockup() {
  return [
    '0xE8b8e9Dc071B83b60c601e3b2F8077B914d083C0',
    new BN('1583971200'), // start timestamp - March 12, 2020
    new BN('0'), // cliff duration
    new BN('15552000'), // vesting duration
    true, // False if tokens are un-revocable from vesting; true if they are
  ];
}

main()
  .then(() => {
    console.log("Finished successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Could not deploy due to error: ", error);
    process.exit(-1);
  });