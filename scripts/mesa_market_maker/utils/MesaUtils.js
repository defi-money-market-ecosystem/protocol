const {throwError} = require('../../GeneralUtils');
const {readContract} = require('../../ContractUtils');

const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : throwError('No ENVIRONMENT specified!');

const getExchangeAddresses = () => {
  let mesaExchangeAddress;
  let mesaExchangeReadAddress;
  if (environment === 'production') {
    mesaExchangeAddress = '0x6F400810b62df8E13fded51bE75fF5393eaa841F'
    mesaExchangeReadAddress = '0x'
  } else if (environment === 'testnet') {
    mesaExchangeAddress = '0x'
    mesaExchangeReadAddress = '0x'
  } else {
    throwError(`Invalid environment, found ${environment}`)
  }
  return {mesaExchangeAddress, mesaExchangeReadAddress};
}

const mapAddressesToTokenIds = async (tokens, web3, artifact, deployer) => {
  const methodName = 'tokenAddressToIdMap';
  for (let i = 0; i < tokens.length; i++) {
    tokens[i] = await readContract(artifact, methodName, [tokens[i]], deployer, web3);
  }
  return tokens;
}

module.exports = {
  getExchangeAddresses,
  mapAddressesToTokenIds,
}