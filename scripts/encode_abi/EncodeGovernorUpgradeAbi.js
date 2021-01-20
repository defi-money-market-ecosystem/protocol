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
  const values = ['0', '0', '0', '0', '0'];
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
  still make deposits (and *only* deposits. This is for interest payments or injecting initial liquidity, for example), 
  but it cannot process withdrawals. As with previous upgrades, we think this moves the DAO further in the direction of 
  being increasingly trust-minimized and autonomous by nature.
  
  The new contracts can be found here:
  - GovernorBeta: [0x4c808e3C011514d5016536aF11218eEc537eB6F5](https://etherscan.io/address/0x4c808e3C011514d5016536aF11218eEc537eB6F5)
  - DmmControllerV2: [0xcC3aB458b20a0115BC7484C0fD53C7962B367955](https://etherscan.io/address/0xcC3aB458b20a0115BC7484C0fD53C7962B367955)
  `;

  await createGovernanceProposal(governorAlpha, targets, values, signatures, calldatas, title, description);
}

module.exports = {
  upgradeGovernorAndControllerContract,
}
