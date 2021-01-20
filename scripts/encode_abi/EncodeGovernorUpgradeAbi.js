const {createGovernanceProposal} = require('./EncodeGovernanceProposalAbi')

const upgradeGovernorAndControllerContract = async(
  governorAlpha,
  newGovernor,
  oldDmmController,
  newDmmController,
  collateralizationCalculator,
  dmmTokens,
  underlyingTokens,
  timelock
) => {
  const targets = [
    timelock,
    newGovernor,
    collateralizationCalculator,
    oldDmmController,
    newDmmController,
  ];
  const values = ['0', '0', '0', '0'];
  const signatures = [
    'setPendingAdmin(address)',
    '__acceptAdmin()',
    'setDmmController(address)',
    'transferOwnershipToNewController(address)',
    'addMarketFromExistingDmmTokens(address[],address[])',
  ];

  const setPendingAdminData = timelock.contract.methods.setPendingAdmin(newGovernor.address).encodeABI();
  const acceptAdminData = newGovernor.contract.methods.__acceptAdmin().encodeABI();
  const setDmmControllerData = collateralizationCalculator.contract.methods.setDmmController(newDmmController.address).encodeABI();
  const transferOwnershipToNewControllerData = oldDmmController.contract.methods.transferOwnershipToNewController(newDmmController.address).encodeABI();
  const addMarketFromExistingDmmTokensData = newDmmController.contract.methods.addMarketFromExistingDmmTokens(dmmTokens, underlyingTokens).encodeABI();
  const calldatas = [
    setPendingAdminData,
    acceptAdminData,
    setDmmControllerData,
    transferOwnershipToNewControllerData,
    addMarketFromExistingDmmTokensData,
  ];

  const title = 'Upgrade Governor Voting Contract and Controller';
  const description = `
  The DMM Ecosystem needs a few things upgraded to stay up-to-date with the latest developments in the ecosystem. 
  Firstly, we are upgrading the *GovernorAlpha* contract to *GovernorBeta* which introduces two key features: the 
  ability to vote using staked DMG in the NFT system, as well as allow contracts to vote on your behalf.
  
  The second set of updates revolve around the DMM Controller. We changed the administrative deposit and 
  withdrawal functions to allow the NFT system to perform these action. The DMM Foundation Safe (the guardian) can 
  still make deposits (for interest payments, for example), but it cannot process withdrawals. As with previous 
  upgrades, we think this moves the DAO further in the direction of being increasingly trust-minimzed and autonomous 
  by nature.
  `;

  await createGovernanceProposal(governorAlpha, targets, values, signatures, calldatas, title, description);
}

module.exports = {
  upgradeGovernorAndControllerContract,
}
