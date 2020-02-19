const {deployContract} = require('./ContractUtils');

global.safeMath = null;
global.dmmTokenLibrary = null;
global.stringHelpers = null;

const deployLibraries = async (loader, environment, deployer) => {
  const SafeMath = loader.truffle.fromArtifact('SafeMath');
  const DmmTokenLibrary = loader.truffle.fromArtifact('DmmTokenLibrary');
  const StringHelpers = loader.truffle.fromArtifact('StringHelpers');

  console.log("Deploying SafeMath...");
  global.safeMath = await deployContract(SafeMath, [], deployer, 4e6);

  console.log("Deploying DmmTokenLibrary...");
  global.dmmTokenLibrary = await deployContract(DmmTokenLibrary, [], deployer, 4e6);

  console.log("Deploying StringHelpers...");
  global.stringHelpers = await deployContract(StringHelpers, [], deployer, 4e6);

  console.log("SafeMath ", safeMath.address);
  console.log("DmmTokenLibrary ", dmmTokenLibrary.address);
  console.log("StringHelpers ", stringHelpers.address);
};

module.exports = {
  deployLibraries,
};