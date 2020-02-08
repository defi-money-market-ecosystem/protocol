module.exports = {
  accounts: {
    amount: 10, // Number of unlocked accounts
    ether: 100, // Initial balance of unlocked accounts (in ether)
  },

  blockGasLimit: 10e6, // Maximum gas per block; 10m

  contracts: {
    type: 'truffle', // Contract abstraction to use: 'truffle' for @truffle/contract or 'web3' for web3-eth-contract
    defaultGas: 8e6, // Maximum gas for contract calls (when unspecified)

    // Options available since v0.1.2
    defaultGasPrice: 20e9, // Gas price for contract calls (when unspecified)
    artifactsDir: 'build/contracts', // Directory where contract artifacts are stored
  },

  provider: 'http://localhost:8545',

};