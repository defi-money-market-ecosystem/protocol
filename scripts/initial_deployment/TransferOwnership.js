const {callContract} = require('../ContractUtils');

const deployOwnershipChanges = async (environment, deployer, guardian) => {
  if (await offChainAssetValuator.owner() !== delayedOwner.address) {
    await transferOwnership('offChainAssetValuator', offChainAssetValuator, delayedOwner.address, deployer);
  }
  if (await offChainCurrencyValuator.owner() !== delayedOwner.address) {
    await transferOwnership('offChainCurrencyValuator', offChainCurrencyValuator, delayedOwner.address, deployer);
  }
  if (environment !== 'LOCAL' && (await dmmEtherFactory.owner() !== dmmController.address)) {
    await transferOwnership('DmmEtherFactory', dmmEtherFactory, dmmController.address, deployer);
  }

  if (environment !== 'LOCAL' && (await dmmTokenFactory.owner()) !== dmmController.address) {
    // It's already transferred by this point, if local.
    await transferOwnership('DmmTokenFactory', dmmTokenFactory, dmmController.address, deployer);
  }

  if ((await dmmBlacklist.owner()) !== delayedOwner.address) {
    await transferOwnership('DmmBlacklist', dmmBlacklist, delayedOwner.address, deployer);
  }

  if ((await dmmController.owner()) !== delayedOwner.address) {
    await transferOwnership('DmmController', dmmController, delayedOwner.address, deployer);
  }

  if (environment !== 'LOCAL' && (await delayedOwner.owner()) !== guardian) {
    await transferOwnership('DelayedOwner', delayedOwner, guardian, deployer);
  }
};

const transferOwnership = async (contractName, contract, newOwner, deployer) => {
  console.log(`Transferring ${contractName}(${contract.address}) ownership to ${newOwner}`);
  await callContract(contract, 'transferOwnership', [newOwner], deployer, 3e5);
};

module.exports = {
  deployOwnershipChanges
};