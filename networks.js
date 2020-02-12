module.exports = {
  networks: {
    development: {
      protocol: 'http',
      host: 'localhost',
      port: 8545,
      gas: 10000000,
      gasPrice: 1e9,
      networkId: '*',
    },
  },
};
