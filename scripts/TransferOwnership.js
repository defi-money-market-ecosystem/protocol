const deployOwnershipChanges = async (environment, multiSigWallet) => {
  await transferOwnership('ChainlinkCollateralValuator', chainlinkCollateralValuator, delayedOwner.address);
  await transferOwnership('DmmEtherFactory', dmmEtherFactory, dmmController.address);
  if (environment !== 'LOCAL') {
    // It's already transferred by this point, if local.
    await transferOwnership('DmmTokenFactory', dmmTokenFactory, dmmController.address);
  }
  await transferOwnership('DmmBlacklist', dmmBlacklist, delayedOwner.address);
  await transferOwnership('DmmController', dmmController, delayedOwner.address);

  if (environment !== 'LOCAL') {
    await transferOwnership('DelayedOwner', delayedOwner, multiSigWallet);
  }
};

const transferOwnership = async (contractName, contract, newOwner) => {
  console.log(`Transferring ${contractName}(${contract.address}) ownership to ${newOwner}`);
  await contract.transferOwnership(newOwner);
};

module.exports = {
  deployOwnershipChanges
};