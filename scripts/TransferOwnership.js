const {callContract} = require('./ContractUtils');

const deployOwnershipChanges = async (environment, deployer, multiSigWallet) => {
  await transferOwnership('OffChainAssetValuatorImplV1', OffChainAssetValuatorImplV1, delayedOwner.address, deployer);
  await transferOwnership('OffChainAssetValuatorImplV1', offChainAssetValuatorImplV1, delayedOwner.address, deployer);
  await transferOwnership('DmmEtherFactory', dmmEtherFactory, dmmController.address, deployer);
  if (environment !== 'LOCAL') {
    // It's already transferred by this point, if local.
    await transferOwnership('DmmTokenFactory', dmmTokenFactory, dmmController.address, deployer);
  }
  await transferOwnership('DmmBlacklist', dmmBlacklist, delayedOwner.address, deployer);
  await transferOwnership('DmmController', dmmController, delayedOwner.address, deployer);

  if (environment !== 'LOCAL') {
    await transferOwnership('DelayedOwner', delayedOwner, multiSigWallet, deployer);
  }
};

const transferOwnership = async (contractName, contract, newOwner, deployer) => {
  console.log(`Transferring ${contractName}(${contract.address}) ownership to ${newOwner}`);
  await callContract(contract, 'transferOwnership', [newOwner], deployer, 3e5);
};

module.exports = {
  deployOwnershipChanges
};