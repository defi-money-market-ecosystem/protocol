const {getGasPriceFromPrompt, throwError} = require('../GeneralUtils');
const nodes = require('../../ethereum-nodes.json');
const environment = process.env.ENVIRONMENT || throwError('No ENVIRONMENT specified!');
const provider = process.env.PROVIDER || environment === 'production' ? nodes.mainnet : nodes.testnet;
const shouldCancel = !!process.env.CANCEL;
const Web3 = require('web3');

const web3 = new Web3(provider);

exports.web3 = web3;

const main = async () => {
  // const privateKey = process.env.DEPLOYER || throwError('Invalid DEPLOYER, found nothing');
  const defaultGasPrice = await getGasPriceFromPrompt();
  const privateKey = require('../mesa_market_maker/utils/data.json').privateKey
  const account = web3.eth.accounts.privateKeyToAccount('0x' + privateKey);
  web3.eth.accounts.wallet.add(account);
  web3.eth.defaultAccount = account.address;

  const oldTransactionHash = process.env.TRANSACTION_HASH;
  const oldTransaction = !!oldTransactionHash ? await web3.eth.getTransaction(oldTransactionHash) : {};

  const transaction = {
    from: (shouldCancel ? account.address : oldTransaction.from) || process.env.FROM,
    to: (shouldCancel ? account.address : oldTransaction.to) || process.env.TO,
    value: (shouldCancel ? '0' : oldTransaction.value) || process.env.TO,
    gas: shouldCancel ? '21000' : oldTransaction.gas,
    gasPrice: defaultGasPrice.toString(),
    data: (shouldCancel ? undefined : oldTransaction.input) || process.env.INPUT,
    nonce: oldTransaction.nonce || process.env.NONCE,
    chainId: 1,
  };

  shouldCancel ?
    console.log('Sending cancellation transaction...')
    :
    console.log('Sending acceleration transaction...');
  await web3.eth.sendTransaction(transaction);
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