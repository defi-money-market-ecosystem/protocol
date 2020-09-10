require('dotenv-flow').config();

module.exports = {
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY,
  },
  compilers: {
    solc: {
      version: '0.5.13',
      docker: false,
      // docker: process.env.DOCKER_COMPILER !== undefined
      //   ? process.env.DOCKER_COMPILER === 'true' : true,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        evmVersion: 'istanbul',
      },
    },
  },
  networks: {
    mainnet: {
      protocol: 'https',
      host: `mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      gas: 10000000,
      gasPrice: process.env.GAS_PRICE,
      network_id: 1,
    },
  },
  plugins: [
    'truffle-plugin-verify'
  ],
}