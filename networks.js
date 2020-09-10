module.exports = {
  networks: {
    development: {
      protocol: 'http',
      host: 'localhost',
      port: 8545,
      gas: 10000000,
      gasPrice: 1e9,
      network_id: '1',
    },
    mainnet: {
      protocol: 'https',
      host: `mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      port: undefined,
      gas: 10000000,
      gasPrice: process.env.GAS_PRICE,
      network_id: 1,
    },
  },
};
