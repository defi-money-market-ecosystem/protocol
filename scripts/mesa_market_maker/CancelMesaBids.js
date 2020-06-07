const Web3 = require('web3');
const {getGasPriceFromPrompt, throwError} = require('../GeneralUtils');
const {callContract, readContract, getAndSetUpDeployer} = require('../ContractUtils');
const {getExchangeAddresses, mapAddressesToTokenIds} = require('./utils/MesaUtils');
const mesaExchangeJson = require('./ABI/MesaExchange.json');

const data = require('./utils/data.json');
const web3 = new Web3(data.provider);

const buyToken = getToken('BUY_TOKEN');
const sellToken = getToken('SELL_TOKEN');

function getToken(key) {
  const errorMessage = `No ${key} specified`;
  return data[process.env[key] || throwError(errorMessage)] || throwError(errorMessage)
}

async function cancelBids() {
  const defaultGasPrice = await getGasPriceFromPrompt();
  const deployer = getAndSetUpDeployer(web3, data.privateKey);
  const {mesaExchangeAddress} = getExchangeAddresses();
  const artifact = {address: mesaExchangeAddress, abi: mesaExchangeJson.abi};
  const methodName = 'cancelOrders';
  const orders = await getOrdersForMarket(buyToken, sellToken, artifact, deployer);
  const orderIds = orders.map(order => order.id);
  const params = [orderIds];
  const gasLimit = 21000 + (orderIds.length * 50000);
  const value = 0;
  await callContract(artifact, methodName, params, deployer, gasLimit, value, web3, defaultGasPrice);
}

async function getOrdersForMarket(buyTokenAddress, sellTokenAddress, artifact, deployer) {
  const tokenIds = await mapAddressesToTokenIds([buyTokenAddress, sellTokenAddress], web3, artifact, deployer);
  const tokenIdsAsHex = tokenIds.map(tokenId => web3.eth.abi.encodeParameter('uint16', tokenId).substring(62));
  const [buyToken, sellToken] = tokenIdsAsHex;

  const methodName = 'getEncodedUserOrders';
  const encodedOrders = (await readContract(artifact, methodName, [deployer], deployer, web3)).substring(2);
  // Elements are packed encoded as:
  // owner_address(address) | sell_balance (uint256) | buy_token (uint8) | sell_token (uint8) | valid_from (uint32) |
  // valid_until (uint32) | price_numerator (uint128) | price_denominator (uint128) | remaining_amount (uint128)
  const perOrderStringLength = 224;
  const length = encodedOrders.length / perOrderStringLength;
  const returnValues = [];
  for (let i = 0; i < length; i++) {
    const order = encodedOrders.substring(i * perOrderStringLength, (i + 1) * perOrderStringLength);
    if (order.substring(104, 108) === buyToken && order.substring(108, 112) === sellToken) {
      returnValues.push({
        id: i,
      });
    }
  }
  return returnValues;
}

cancelBids()
  .then(() => {
    console.log('Successfully cancelled the specified bids');
  })
  .catch(error => {
    console.error('Could not cancel bids due to error: ', error);
  })