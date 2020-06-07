const Web3 = require('web3');
const {callContract, getAndSetUpDeployer} = require('../ContractUtils');
const {getGasPriceFromPrompt, throwError} = require('../GeneralUtils');
const {getExchangeAddresses} = require('./utils/MesaUtils');
const mesaExchangeJson = require('./ABI/MesaExchange.json');

const data = require('./utils/data.json');
const web3 = new Web3(data.provider);
const tokenAddress = data[!!process.env.TICKER ? process.env.TICKER : throwError('No TICKER specified')];

async function withdraw() {
  const defaultGasPrice = await getGasPriceFromPrompt();
  const deployer = getAndSetUpDeployer(web3, data.privateKey);
  const {mesaExchangeAddress} = getExchangeAddresses();
  const artifact = {address: mesaExchangeAddress, abi: mesaExchangeJson.abi};
  const params = [deployer, tokenAddress];
  const gasLimit = 200000;
  const value = 0;
  await callContract(artifact, 'withdraw', params, deployer, gasLimit, value, web3, defaultGasPrice);
}

withdraw()
  .then(() => {
    console.log(`Successfully withdrew ${process.env.TICKER}`);
  })
  .catch(error => {
    console.error(`Could not withdraw ${process.env.TICKER} to error: `, error);
  })