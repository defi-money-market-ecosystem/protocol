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
  const length = 30;

  const buyTokenAddresses = Array(length).fill().map(() => data.WETH)
  const buyTokens = await mapAddressesToTokenIds(
    buyTokenAddresses,
    web3,
    artifact,
    deployer,
  );

  const sellTokenAddresses = Array(length).fill().map(() => data.DMG)
  const sellTokens = await mapAddressesToTokenIds(
    sellTokenAddresses,
    web3,
    artifact,
    deployer,
  );

  const fromBatchIds = Array(length).fill().map(() => new BN('5309436')); // June 22 @ 9 AM EST, sharp.
  const toBatchIds = fromBatchIds.map((unused, index) => fromBatchIds[index].mul(new BN('100000')));
  const sellAmount = new BN('83333000000000000000000')
  const buyAmounts = Array(length).fill().map((unused, index) => {
    const price = new BN('1531910000000000');
    const bondingCurvePower = new BN('1015').pow(new BN(index.toString()));
    const bondingCurveBase = new BN('1000').pow(new BN(index.toString()));
    const buyAmountRaw = price.mul(bondingCurvePower).div(bondingCurveBase).mul(sellAmount);
    return buyAmountRaw.div(new BN('1000000000000000000')).toString();
  });
  const sellAmounts = Array(length).fill().map(() => sellAmount.toString());
  console.log('sellAmounts ', sellAmounts);
  console.log('buyAmounts ', buyAmounts);
  const methodName = 'placeValidFromOrders'
  const params = [
    buyTokens,
    sellTokens,
    fromBatchIds,
    toBatchIds,
    buyAmounts,
    sellAmounts,
  ];
  const gasLimit = 21000 + (params[0].length * 115000);
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