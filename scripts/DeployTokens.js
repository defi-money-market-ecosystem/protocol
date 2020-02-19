const {BN} = require('ethereumjs-util');
const {deployContract, callContract} = require('./ContractUtils');

global.dai = null;
global.link = null;
global.usdc = null;
global.weth = null;

const deployTokens = async (loader, environment, deployer) => {
  if (environment === 'LOCAL') {
    const ERC20Mock = loader.truffle.fromArtifact('ERC20Mock');
    const WETH = loader.truffle.fromArtifact('WETHMock');

    dai = await deployContract(ERC20Mock, [], deployer, 6e6);
    link = await deployContract(ERC20Mock, [], deployer, 6e6);
    usdc = await deployContract(ERC20Mock, [], deployer, 6e6);
    weth = await deployContract(WETH, [], deployer, 6e6);

    const recipient = '0x8D7f03FdE1A626223364E592740a233b72395235';
    await callContract(dai, 'setBalance', [recipient, new BN('100000000000000000000')], deployer, 3e5);
    await callContract(usdc, 'setBalance', [recipient, new BN('100000000')], deployer, 3e5);
    await callContract(weth, 'setBalance', [recipient, new BN('1000000000000000000')], deployer, 3e5);
  } else if (environment === 'TESTNET') {
    const ERC20Mock = loader.truffle.fromArtifact('ERC20Mock');
    const WETH = loader.truffle.fromArtifact('WETHMock');

    dai = await deployContract(ERC20Mock, [], deployer, 6e6);
    link = loader.truffle.fromArtifact('ERC20', '0x01BE23585060835E02B77ef475b0Cc51aA1e0709');
    usdc = await deployContract(ERC20Mock, [], deployer, 6e6);
    weth = await deployContract(WETH, [], deployer, 6e6);

    const recipient = '0x8D7f03FdE1A626223364E592740a233b72395235';
    await callContract(dai, 'setBalance', [recipient, new BN('100000000000000000000')], deployer, 3e5);
    await callContract(usdc, 'setBalance', [recipient, new BN('100000000')], deployer, 3e5);
    await callContract(weth, 'setBalance', [recipient, new BN('1000000000000000000')], deployer, 3e5);
    await callContract(weth, 'deposit', [], deployer, 3e5, new BN('1000000000000000000'));
  } else if (environment === 'PRODUCTION') {
    dai = loader.truffle.fromArtifact('ERC20', '0x6b175474e89094c44da98b954eedeac495271d0f');
    link = loader.truffle.fromArtifact('ERC20', '0x514910771af9ca656af840dff83e8264ecf986ca');
    usdc = loader.truffle.fromArtifact('ERC20', '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48');
    weth = loader.truffle.fromArtifact('ERC20', '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2');
  } else {
    new Error('Invalid environment, found ' + environment);
  }

  console.log("DAI: ", dai.address);
  console.log("LINK: ", link.address);
  console.log("USDC: ", usdc.address);
  console.log("WETH: ", weth.address);
};

module.exports = {
  deployTokens
};