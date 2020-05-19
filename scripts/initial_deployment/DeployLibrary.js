const {deployContract} = require('../ContractUtils');

global.safeMath = null;
global.dmmTokenLibrary = null;
global.stringHelpers = null;

const deployLibraries = async (loader, environment, deployer) => {
  const SafeMath = loader.truffle.fromArtifact('SafeMath');
  const DmmTokenLibrary = loader.truffle.fromArtifact('DmmTokenLibrary');
  const StringHelpers = loader.truffle.fromArtifact('StringHelpers');

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    global.safeMath = loader.truffle.fromArtifact('SafeMath', "0x11Cbf7dAFB3E913a96b2E3E78Ca20c0D24301b27");
  } else if (environment !== 'PRODUCTION') {
    console.log("Deploying SafeMath...");
    global.safeMath = await deployContract(SafeMath, [], deployer, 4e6);
  } else {
    global.safeMath = loader.truffle.fromArtifact('SafeMath', "0xB2Daada8A1eb9286776619929Bb160C3161FD3aF");
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    global.dmmTokenLibrary = loader.truffle.fromArtifact('DmmTokenLibrary', "0x336dae1124F00b7139f96972Bd2B7e56B7250993");
  } else if (environment !== 'PRODUCTION') {
    console.log("Deploying DmmTokenLibrary...");
    global.dmmTokenLibrary = await deployContract(DmmTokenLibrary, [], deployer, 4e6);
  } else {
    global.dmmTokenLibrary = loader.truffle.fromArtifact('DmmTokenLibrary', "0x7D06ACB02165131C2aEA372210a0E6293f9165B3");
  }

  if (environment === 'TESTNET' && process.env.REUSE === 'true') {
    global.stringHelpers = loader.truffle.fromArtifact('StringHelpers', "0x96E6eE3D0E10D8692a08A50D0bd0534Ed651344C");
  } else if (environment !== 'PRODUCTION') {
    console.log("Deploying StringHelpers...");
    global.stringHelpers = await deployContract(StringHelpers, [], deployer, 4e6);
  } else {
    global.stringHelpers = loader.truffle.fromArtifact('StringHelpers', "0x50adD802Bbe45d06ac5d52bF3CDAC40f8648cf95");
  }

  console.log("SafeMath ", safeMath.address);
  console.log("DmmTokenLibrary ", dmmTokenLibrary.address);
  console.log("StringHelpers ", stringHelpers.address);
};

module.exports = {
  deployLibraries,
};