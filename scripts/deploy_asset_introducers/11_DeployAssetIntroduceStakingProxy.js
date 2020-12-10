const {throwError} = require('../GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No PROVIDER specified!');
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {BN} = require('ethereumjs-util');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract, callContract} = require('../ContractUtils');
const {
  assetIntroducerProxyAddress,
  assetIntroducerStakingV1Address,
  dmgIncentivePoolAddress,
  defaultGasPrice,
} = require('./index');

const web3 = new Web3(provider);

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

  let guardian;
  if (process.env.GUARDIAN_ADDRESS) {
    guardian = process.env.GUARDIAN_ADDRESS
    if (guardian.toLowerCase() !== '0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF'.toLowerCase()) {
      throw Error('Is this a correct guardian? Did not find 0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF. Comment this out, if so.')
    }
  } else {
    throw Error('No guardian specified!')
  }

  const loader = setupLoader({provider: web3, defaultSender: deployer, defaultGasPrice: 8e9});

  const AssetIntroducerStakingProxy = loader.truffle.fromArtifact('AssetIntroducerStakingProxy');
  await deployContract(
    AssetIntroducerStakingProxy,
    [assetIntroducerStakingV1Address, guardian, assetIntroducerProxyAddress, dmgIncentivePoolAddress],
    deployer,
    7e5,
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