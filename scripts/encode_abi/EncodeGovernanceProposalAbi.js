const createProposalForYieldFarming = async (governorAlpha, safeAddress, dmg, farmSeasonAmount, dmmDeployerAddress, timelockAddress, yieldFarming) => {
  const transferSignature = 'transferFrom(address,address,uint256)';
  const transferCallData = dmg.contract.methods.transferFrom(dmmDeployerAddress, timelockAddress, farmSeasonAmount).encodeABI().substring(10);

  const approveSignature = 'approve(address,uint256)';
  const approveCallData = dmg.contract.methods.approve(yieldFarming.address, farmSeasonAmount).encodeABI().substring(10);

  const beginFarmingCampaignSignature = 'beginFarmingSeason(uint256)';
  const beginFarmingCampaignCallData = yieldFarming.contract.methods.beginFarmingSeason(farmSeasonAmount).encodeABI().substring(10);

  const targets = [dmg, dmg, yieldFarming];
  const values = ['0', '0', '0'];
  const signatures = [transferSignature, approveSignature, beginFarmingCampaignSignature]
  const calldatas = [`0x${transferCallData}`, `0x${approveCallData}`, `0x${beginFarmingCampaignCallData}`];
  const title = 'Introduce Yield Farming';
  const description = `
  Yield Farming is the process whereby mToken holders can deposit their mTokens, plus an equivalent amount of underlying 
  tokens, into the \`DMM: Yield Farming\` contract to earn DMG. In doing so, ecosystem participants can be additionally 
  incentivized to deposit funds into the protocol.
  
  For more information about yield farming and how it works, visit our Medium [article](https://medium.com).
  `;

  await createGovernanceProposal(
    governorAlpha,
    targets,
    values,
    signatures,
    calldatas,
    title,
    description,
  );
}

const createProposalForDryRun = async (governorAlpha, safeAddress) => {
  const dryRunSignature = 'dryRun()';
  const dryRunCallData = '0x0';
  const targets = [{address: safeAddress}];
  const values = ['0'];
  const signatures = [dryRunSignature]
  const calldatas = [dryRunCallData];
  const title = 'Test out Voting!';
  const description = `
  Voting requires that you activate your wallet in order to vote. Upon activation, your wallet will receive ballots
  equal to your DMG token balance. Once enough users have activated their wallets, we will create the first proposal
  for the community to ratify the onboarding of USDT to the ecosystem.
  
  To activate your wallet, press the *ACTIVATE WALLET* button on the main page of the voting dashboard.
  `;

  await createGovernanceProposal(
    governorAlpha,
    targets,
    values,
    signatures,
    calldatas,
    title,
    description,
  );
}

const createProposalForAddingUsdt = async (governorAlpha, dmmController, usdtAddress, underlyingTokenValuatorImplV4Address) => {
  const addMarketSignature = 'addMarket(address,string,string,uint8,uint256,uint256,uint256)';
  const setUnderlyingTokenValuatorSignature = 'setUnderlyingTokenValuator(address)';

  if (!dmmController.contract.methods[addMarketSignature]) {
    throw Error('Invalid addMarketSignature, found ' + addMarketSignature)
  }
  if (!dmmController.contract.methods[setUnderlyingTokenValuatorSignature]) {
    throw Error('Invalid setUnderlyingTokenValuatorSignature, found ' + setUnderlyingTokenValuatorSignature)
  }

  const addMarketCalldata = '0x' + dmmController.contract.methods.addMarket(
    usdtAddress,
    'mUSDT',
    'DMM: USDT',
    6,
    '1',
    '1',
    '8000000000000',
  ).encodeABI().substring(10);

  const setUnderlyingTokenValuatorCalldata = '0x' + dmmController.contract.methods.setUnderlyingTokenValuator(
    underlyingTokenValuatorImplV4Address,
  ).encodeABI().substring(10);

  const targets = [dmmController, dmmController];
  const values = ['0', '0'];
  const signatures = [addMarketSignature, setUnderlyingTokenValuatorSignature]
  const calldatas = [addMarketCalldata, setUnderlyingTokenValuatorCalldata];
  const title = 'Add Support for USDT (mUSDT)';
  const description = `
  The [USD Tether (USDT) stablecoin](https://tether.to) is the most liquid stablecoin in the world as of today - August 12, 2020.
  
  As our first vote for the ecosystem, we think that onboarding USDT with a debt ceiling of 8,000,000 USDT will bring new
  heights to the DMM Protocol's usage. From the protocol's perspective, the goal is to grow the amount of stablecoins
  deposited, so the DAO can onboard the next asset - [two private PC-12 planes](https://medium.com/dmm-dao/introducing-aviation-assets-into-the-dmm-ecosystem-a7310970291c).
  
  As with all votes, the passing of this proposal will (relatively) immediately create the mUSDT token. All necessary
  logic to trustlessly create the token will automatically execute if this proposal passes.
  `;

  await createGovernanceProposal(
    governorAlpha,
    targets,
    values,
    signatures,
    calldatas,
    title,
    description,
  );
}

const createProposalForUpgradingController = async (
  governorAlpha,
  dmmController,
  usdt,
  newDmmController,
  gnosisSafeAddress,
  newDmmTokenFactoryAddress,
  daiAddress,
  usdcAddress,
  wethAddress,
  mDaiAddress,
  mUsdcAddress,
  mWethAddress,
) => {
  const setMinReserveRatio = 'setMinReserveRatio(uint256)';
  const adminWithdrawFunds = 'adminWithdrawFunds(uint256,uint256)';
  const transferFunds = 'transfer(address,uint256)';
  const transferOwnershipToNewController = 'transferOwnershipToNewController(address)';
  const addMarketFromExistingDmmToken = 'addMarketFromExistingDmmToken(address,address)';

  if (!dmmController.contract.methods[setMinReserveRatio]) {
    throw Error('Invalid setMinReserveRatio, found ' + setMinReserveRatio)
  }
  if (!dmmController.contract.methods[adminWithdrawFunds]) {
    throw Error('Invalid adminWithdrawFunds, found ' + adminWithdrawFunds)
  }
  if (!usdt.contract.methods[transferFunds]) {
    throw Error('Invalid transferFunds, found ' + transferFunds)
  }
  if (!dmmController.contract.methods[transferOwnershipToNewController]) {
    throw Error('Invalid transferOwnershipToNewController, found ' + transferOwnershipToNewController)
  }
  if (!dmmController.contract.methods[addMarketFromExistingDmmToken]) {
    throw Error('Invalid addMarketFromExistingDmmToken, found ' + addMarketFromExistingDmmToken)
  }

  const setMinReserveRatioCalldata = '0x' + dmmController.contract.methods.setMinReserveRatio(
    '0',
  ).encodeABI().substring(10);
  const adminWithdrawFundsCalldata = '0x' + dmmController.contract.methods.adminWithdrawFunds(
    '4',
    '489827072240',
  ).encodeABI().substring(10);
  const transferFundsCalldata = '0x' + usdt.contract.methods.transfer(
    gnosisSafeAddress,
    '489827072240'
  ).encodeABI().substring(10);
  const transferOwnershipToNewControllerCalldata = '0x' + dmmController.contract.methods.transferOwnershipToNewController(
    newDmmController.address,
  ).encodeABI().substring(10);
  const daiMigrationCalldata = '0x' + dmmController.contract.methods.addMarketFromExistingDmmToken(
    mDaiAddress,
    daiAddress,
  ).encodeABI().substring(10);
  const usdcMigrationCalldata = '0x' + dmmController.contract.methods.addMarketFromExistingDmmToken(
    mUsdcAddress,
    usdcAddress,
  ).encodeABI().substring(10);
  const wethMigrationCalldata = '0x' + dmmController.contract.methods.addMarketFromExistingDmmToken(
    mWethAddress,
    wethAddress,
  ).encodeABI().substring(10);

  const targets = [dmmController, dmmController, usdt, dmmController, newDmmController, newDmmController, newDmmController];
  const values = ['0', '0', '0', '0', '0', '0', '0'];
  const signatures = [setMinReserveRatio, adminWithdrawFunds, transferFunds, transferOwnershipToNewController, addMarketFromExistingDmmToken, addMarketFromExistingDmmToken, addMarketFromExistingDmmToken]
  const calldatas = [setMinReserveRatioCalldata, adminWithdrawFundsCalldata, transferFundsCalldata, transferOwnershipToNewControllerCalldata, daiMigrationCalldata, usdcMigrationCalldata, wethMigrationCalldata];
  const title = 'Upgrade the DMM Ecosystem';
  const description = `
  The DMM Ecosystem Controller is missing some utility functions that could greatly improve the usability of the 
  protocol. In addition, interest payments, which are currently brought on-chain via the Foundation must be voted into 
  the ecosystem. Rather, the new controller introduces the concept of a "guardian" which has the privilege to deposit 
  interest payments, in addition to the DAO.
  
  The last fix revolves around tokens that do not conform to the ERC20 standard exactly. We have upgraded the DMM Token 
  Factory contract to use new source code that utilizes the Open Zeppelin "safeTransfer" function when transferring the 
  underlying funds out of the DMM mToken contract.
  
  The address of the new and verified controller is [${newDmmController.address}}](https://etherscan.io/address/${newDmmController.address}).
  
  The address of the new and verified DMM Token Factory is [${newDmmTokenFactoryAddress}](https://etherscan.io/address/${newDmmTokenFactoryAddress}).
  `;

  await createGovernanceProposal(
    governorAlpha,
    targets,
    values,
    signatures,
    calldatas,
    title,
    description,
  );
}

const createGovernanceProposal = async (governorAlpha, targets, values, signatures, calldatas, title, description) => {
  targets.forEach((target, index) => {
    if (target.contract) {
      if (!target.contract.methods[signatures[index]]) {
        throw Error(`Cannot find method for contract index=${index} signature=${signatures[index]}`)
      }
    } else {
      throw `Could not verify ${target} at index ${index}`
    }
  })

  const actualAbi = governorAlpha.contract.methods.propose(
    targets.map(target => target.address),
    values,
    signatures,
    calldatas,
    title,
    description
  ).encodeABI();

  console.log(`createGovernanceProposal at ${governorAlpha.address} `, actualAbi);
};

module.exports = {
  createProposalForYieldFarming,
  createProposalForUpgradingController,
  createProposalForAddingUsdt,
  createProposalForDryRun,
};