const provider = process.env.PROVIDER ? process.env.PROVIDER : 'http://localhost:8545';
const environment = process.env.ENVIRONMENT ? process.env.ENVIRONMENT : new Error('No ENVIRONMENT specified!');
const Web3 = require('web3');
const {BN} = require('ethereumjs-util');

const web3 = new Web3(provider);

const _1 = new BN('1000000000000000000');

const main = async () => {
  const deployer = (await web3.eth.getAccounts())[0];
  await web3.eth.sendTransaction({from: deployer, to: process.env.RECIPIENT, value: _1})
};

main()
  .then(() => {
    console.log("Finished successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Could not deploy due to error: ", error);
    process.exit(-1);
  });