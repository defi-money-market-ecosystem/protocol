const {throwError} = require('../GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError('No PROVIDER specified!');
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {BN} = require('ethereumjs-util');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {deployContract, linkContract} = require('../ContractUtils');
const {
  assetIntroducerDiscountAddress,
  assetIntroducerV1Address,
  dmgTokenAddress,
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

  const openSeaProxy = '0xa5409ec958C83C3f309868babACA7c86DCB077c1';
  const owner = '0xE679eBf544A6BE5Cb8747012Ea6B08F04975D264';
  const dmmController = '0xB07EB3426d742cda9120931e7028d54F9dF34A3e';
  const underlyingTokenValuator = '0xaC7e5e3b589D55a43D62b90c6b4C4ef28Ea35573';

  const AssetIntroducerProxy = loader.truffle.fromArtifact('AssetIntroducerProxy');
  await deployContract(
    AssetIntroducerProxy,
    [
      assetIntroducerV1Address,
      guardian,
      'https://api.defimoneymarket.com/v1/asset-introducers/',
      openSeaProxy,
      owner,
      guardian,
      dmgTokenAddress,
      dmmController,
      underlyingTokenValuator,
      assetIntroducerDiscountAddress,
    ],
    deployer,
    1e6,
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