const Web3 = require('web3');
const {BN} = require('ethereumjs-util');
const {getGasPriceFromPrompt, throwError} = require('../GeneralUtils');
const {callContract, getAndSetUpDeployer} = require('../ContractUtils');
const {getExchangeAddresses} = require('./utils/MesaUtils');
const mesaExchangeJson = require('./ABI/MesaExchange.json');

const data = require('./utils/data.json');
const web3 = new Web3(data.provider);
const tokenAddress = data[!!process.env.TICKER ? process.env.TICKER : throwError('No TICKER specified')];
const amountBN = new BN(!!process.env.AMOUNT ? process.env.AMOUNT : throwError('No AMOUNT specified'));

async function requestWithdraw() {
  const defaultGasPrice = await getGasPriceFromPrompt();
  const deployer = getAndSetUpDeployer(web3, data.privateKey);
  const {mesaExchangeAddress} = getExchangeAddresses();
  const artifact = {address: mesaExchangeAddress, abi: mesaExchangeJson.abi};
  const params = [tokenAddress, amountBN];
  const gasLimit = 100000;
  const value = 0;
  await callContract(artifact, 'requestWithdraw', params, deployer, gasLimit, value, web3, defaultGasPrice);
}

requestWithdraw()
  .then(() => {
    console.log(`Successfully requested a withdrawal for ${process.env.TICKER}`);
  })
  .catch(error => {
    console.error(`Could not request a withdrawal for ${process.env.TICKER} to error: `, error);
  })