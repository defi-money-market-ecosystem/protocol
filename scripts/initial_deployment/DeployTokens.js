const {BN} = require('ethereumjs-util');
const {deployContract, callContract} = require('../ContractUtils');

global.dai = null;
global.link = null;
global.usdc = null;
global.weth = null;

const deployTokens = async (loader, environment, deployer) => {
  if (environment === 'LOCAL') {
    const ERC20Test = loader.truffle.fromArtifact('ERC20Test');
    const WETH = loader.truffle.fromArtifact('WETHMock');

    dai = await deployContract(ERC20Test, ['Dai', 'DAI', 18], deployer, 6e6);
    link = await deployContract(ERC20Test, ['Chainlink Token', 'LINK', 18], deployer, 6e6);
    usdc = await deployContract(ERC20Test, ['USD//C', 'USDC', 6], deployer, 6e6);
    weth = await deployContract(WETH, [], deployer, 6e6);

    const recipient = '0x8D7f03FdE1A626223364E592740a233b72395235';
    await callContract(dai, 'setBalance', [recipient, new BN('100000000000000000000')], deployer, 3e5);
    await callContract(usdc, 'setBalance', [recipient, new BN('100000000')], deployer, 3e5);
    await callContract(weth, 'setBalance', [recipient, new BN('1000000000000000000')], deployer, 3e5);
  } else if (environment === 'TESTNET') {
    const ERC20Test = loader.truffle.fromArtifact('ERC20Test');
    const WETH = loader.truffle.fromArtifact('WETHMock');

    if (process.env.REUSE === 'true') {
      dai = loader.truffle.fromArtifact('ERC20Test', '0xf15a6519b099A8eb7ffA9f12AF0D878B0f85a918');
      link = loader.truffle.fromArtifact('ERC20Test', '0x01BE23585060835E02B77ef475b0Cc51aA1e0709');
      usdc = loader.truffle.fromArtifact('ERC20Test', '0x54db15edFb7552f0314e89966afa6C89ff157386');
      weth = loader.truffle.fromArtifact('WETHMock', '0x893178fBD1b3eb77cB85Ab39Bb3b3EDF2609a478');
    } else {
      dai = await deployContract(ERC20Test, ['Dai Stablecoin', 'DAI', 18], deployer, 6e6);
      link = loader.truffle.fromArtifact('ERC20', '0x01BE23585060835E02B77ef475b0Cc51aA1e0709');
      usdc = await deployContract(ERC20Test, ['USD//C', 'USDC', 6], deployer, 6e6);
      weth = await deployContract(WETH, [], deployer, 6e6);

      const recipient = '0x8D7f03FdE1A626223364E592740a233b72395235';
      await callContract(dai, 'setBalance', [recipient, new BN('100000000000000000000')], deployer, 3e5);
      await callContract(usdc, 'setBalance', [recipient, new BN('100000000')], deployer, 3e5);
      await callContract(weth, 'setBalance', [recipient, new BN('1000000000000000000')], deployer, 3e5);
      await callContract(weth, 'deposit', [], deployer, 3e5, new BN('100000000000000000'));
    }
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