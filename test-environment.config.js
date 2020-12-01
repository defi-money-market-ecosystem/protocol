module.exports = {
  accounts: {
    amount: 10, // Number of unlocked accounts
    ether: 1000000, // Initial balance of unlocked accounts (in ether)
  },

  contracts: {
    type: 'truffle', // Contract abstraction to use: 'truffle' for @truffle/contract or 'web3' for web3-eth-contract
    defaultGas: 8e6, // Maximum gas for contract calls (when unspecified)

    // Options available since v0.1.2
    defaultGasPrice: 20e9, // Gas price for contract calls (when unspecified)
    artifactsDir: 'build/contracts', // Directory where the contract artifacts are stored
  },

  gasLimit: 10e6, // Maximum gas per block; 10m

  // setupProvider: () => {
  //   const Web3 = require('web3');
  //   return new Web3.providers.HttpProvider('http://localhost:8545');
  // },

};