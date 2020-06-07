const Web3 = require('web3');
const {BN} = require('ethereumjs-util')
const {getGasPriceFromPrompt} = require('../GeneralUtils');
const {callContract, readContract, getAndSetUpDeployer} = require('../ContractUtils');
const {getExchangeAddresses, mapAddressesToTokenIds} = require('./utils/MesaUtils');
const mesaExchangeJson = require('./ABI/MesaExchange.json');


const data = require('./utils/data.json');
const web3 = new Web3(data.provider);

async function placeBids() {
  const defaultGasPrice = await getGasPriceFromPrompt();
  const deployer = getAndSetUpDeployer(web3, data.privateKey);
  const {mesaExchangeAddress} = getExchangeAddresses();
  const artifact = {address: mesaExchangeAddress, abi: mesaExchangeJson.abi};

  // const currentBatchId = await readContract(artifact, '')

  const buyTokens = await mapAddressesToTokenIds(
    [data.DAI, data.DAI],
    web3,
    artifact,
    deployer,
  );
  const sellTokens = await mapAddressesToTokenIds(
    [data.DMG, data.DMG],
    web3,
    artifact,
    deployer,
  );

  const latestBatchId = await readContract(artifact, 'getCurrentBatchId', [], deployer, web3);
  const fromBatchId = new BN(latestBatchId).add(new BN(1));
  const toBatchId = fromBatchId.mul(new BN('100000'));
  const sellAmount = new BN('83333000000000000000000')
  const methodName = 'placeValidFromOrders'
  const params = [
    buyTokens,
    sellTokens,
    [fromBatchId, fromBatchId],
    [toBatchId, toBatchId],
    [new BN('11212270000000000000000'), new BN('13533330000000000000000')],
    [sellAmount, sellAmount],
  ];
  const gasLimit = 21000 + (params[0].length * 125000);
  const value = 0;
  await callContract(artifact, methodName, params, deployer, gasLimit, value, web3, defaultGasPrice);
}

placeBids()
  .then(() => {
    console.log('Successfully placed bids');
  })
  .catch(error => {
    console.error('Could not place bids due to error: ', error);
  })