global.safeMath = null;
global.dmmTokenLibrary = null;
global.stringHelpers = null;

const deployLibraries = async (loader, environment) => {
  const SafeMath = loader.truffle.fromArtifact('SafeMath');
  const DmmTokenLibrary = loader.truffle.fromArtifact('DmmTokenLibrary');
  const StringHelpers = loader.truffle.fromArtifact('StringHelpers');

  if (environment === 'LOCAL') {
    global.safeMath = await SafeMath.new();
    global.dmmTokenLibrary = await DmmTokenLibrary.new();
    global.stringHelpers = await StringHelpers.new();
  } else if (environment === 'TESTNET') {
    global.safeMath = await SafeMath.new();
    global.dmmTokenLibrary = await DmmTokenLibrary.new();
    global.stringHelpers = await StringHelpers.new();
  } else if (environment === 'PRODUCTION') {
    global.safeMath = await SafeMath.new();
    global.dmmTokenLibrary = await DmmTokenLibrary.new();
    global.stringHelpers = await StringHelpers.new();
  } else {
    new Error('Invalid environment, found ' + environment);
  }

  console.log("SafeMath ", safeMath.address);
  console.log("DmmTokenLibrary ", dmmTokenLibrary.address);
  console.log("StringHelpers ", stringHelpers.address);
};

module.exports = {
  deployLibraries,
};