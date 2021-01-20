const BN = require('bn.js');
const Web3 = require('web3');

const createProposalForYieldFarming = async (governorAlpha, safeAddress, dmg, dmmDeployerAddress, timelockAddress, yieldFarming, rewardAmountWei, targetDurationDays, maxDebtCeilingWei) => {
  const dmgGrowthCoefficient = rewardAmountWei.div(new BN('86400')).div(targetDurationDays).div(maxDebtCeilingWei);
  console.log('dmgGrowthCoefficient ', dmgGrowthCoefficient.toString());

  const itersWei = new BN('1000000')
  const apr = new BN('365').mul(itersWei).div(targetDurationDays).mul(rewardAmountWei).div(maxDebtCeilingWei).div(itersWei)
  console.log(`Proposed APR for this campaign: ${new Web3('').utils.fromWei(apr)}`)

  const transferSignature = 'transferFrom(address,address,uint256)';
  const transferCallData = dmg.contract.methods.transferFrom(dmmDeployerAddress, timelockAddress, rewardAmountWei.toString()).encodeABI().substring(10);

  const approveSignature = 'approve(address,uint256)';
  const approveCallData = dmg.contract.methods.approve(yieldFarming.address, rewardAmountWei.toString()).encodeABI().substring(10);

  const setDmgGrowthCoefficientSignature = 'setDmgGrowthCoefficient(uint256)';
  console.log('dmgGrowthCoefficient.toString() ', dmgGrowthCoefficient.toString())
  const setDmgGrowthCoefficientCallData = yieldFarming.contract.methods.setDmgGrowthCoefficient(dmgGrowthCoefficient.toString()).encodeABI().substring(10);

  const beginFarmingCampaignSignature = 'beginFarmingSeason(uint256)';
  const beginFarmingCampaignCallData = yieldFarming.contract.methods.beginFarmingSeason(rewardAmountWei.toString()).encodeABI().substring(10);

  const targets = [dmg, dmg, yieldFarming, yieldFarming];
  const values = ['0', '0', '0', '0'];
  const signatures = [transferSignature, approveSignature, setDmgGrowthCoefficientSignature, beginFarmingCampaignSignature]
  const calldatas = [`0x${transferCallData}`, `0x${approveCallData}`, `0x${setDmgGrowthCoefficientCallData}`, `0x${beginFarmingCampaignCallData}`];
  const title = 'Introduce Yield Farming';
  const description = `
  Yield Farming is the process whereby mToken holders can deposit their mTokens, plus an equivalent amount of underlying 
  tokens, into the \`DMM: Yield Farming\` contract to earn DMG. The DMG that is earned from doing so, is said to be 
  farmed into existence, since ecosystem participants are rewarded for depositing (planting) their stake in the 
  farming contract. Essentially, yield farming incentivizes all users to deposit funds into the protocol to earn a 
  higher ROI, because all deposits into the yield farming contract accrue DMG *on top of* the ordinary 6.25%.
  
  Yield farming is partitioned by season, allowing the DAO to turn a growth "lever" on and off as it needs to 
  encourage further growth of the ecosystem. This vote enables the first season by funding the yield farming contract
  with 1,000,000 DMG. Assuming moderate to high levels of participation, this first season should last around 30 days.
  This translates to an *additional* APR of about 30-60% (meaning, the effective APR of a user's active farm is 
  36.25-66.25%). This APR is produced by the value of the DMG being distributed as a promotional incentive for each 
  community member's contribution to the ecosystem, and it assumes the DMG price hovers around $1.00. The APR can also 
  vary depending on the composition of the farm's tokens and its treasury. Depending on the  participation and success 
  of this first season, the DMMF will likely propose different seasonal amounts in the future. There are no lock up 
  periods with farming, and participants are free to withdraw their mTokens + earned DMG at any time.
  
  Risk: The smart contracts deployed for yield farming **have not been audited by a third party**. With that being said, 
  we have architected these contracts using best practices and have robust test coverage for all functions to give us
  a high degree of confidence that their implementation matches their intended use. Additionally, we have taken 
  simplification steps to reduce attack vectors, such as making DMM yield farming contract **not** tokenized. Meaning, 
  deposits are effectively a closed-loop; once they are made, there is no way to transfer deposits or mix them them with 
  other dapps. All writeable functions use Open Zeppelin's Reentrancy Guard to prevent against possible re-entrancy 
  attacks. Lastly, all token transfers utilize Open Zeppelin's \`safeTransfer\` or \`safeTransferFrom\` functions to 
  ensure slight deviations from the ERC20 standard doesn't result in any hiccups.
  
  For additional information about yield farming and how it works, visit the DMMF's 
  [Medium article](https://medium.com/dmm-dao/introducing-yield-farming-into-the-dmm-ecosystem-8e33a45fc226).
  
  The address of the verified Yield Farming contract is [${yieldFarming.address}}](https://etherscan.io/address/${yieldFarming.address}).
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

const createProposalForAddingWbtc = async (governorAlpha, dmmController, wbtcAddress) => {
  const addMarketSignature = 'addMarket(address,string,string,uint8,uint256,uint256,uint256)';

  if (!dmmController.contract.methods[addMarketSignature]) {
    throw Error('Invalid addMarketSignature, found ' + addMarketSignature)
  }

  const addMarketCalldata = '0x' + dmmController.contract.methods.addMarket(
    wbtcAddress,
    'mWBTC',
    'DMM: WBTC',
    8,
    '1', // 0.00000001
    '1', // 0.00000001
    '2500000000', // 25 WBTC
  ).encodeABI().substring(10);

  const targets = [dmmController];
  const values = ['0'];
  const signatures = [addMarketSignature]
  const calldatas = [addMarketCalldata];
  const title = 'Add Support for WBTC (mWBTC)';
  const description = `
  The DMM Foundation would like to propose the addition of [WBTC](https://wbtc.network/) to the DMM Ecosystem with a
  debt ceiling of 25 WBTC. Using BTC's recent all-time-highs, this would equal roughly $1,000,000. While we think the 
  usage of WBTC may attempt to exceed the debt ceiling in the short-term, a fundamental goal that the DMM Foundation is 
  actively pursuing is putting in place an acceptable hedge that would allow asset introducers to draw down WBTC and 
  fund the acquisition of more real-world assets to accrue yield for the system.
  
  WBTC is an ERC20 token that is 1:1 backed by BTC from the Bitcoin Blockchain. Each BTC that backs the system is held 
  in a reserve by [BitGo](https://www.bitgo.com/) - an industry-leading custodian that has been working with the WBTC
  project since its launch in early 2019. With the addition of WBTC to the DMM Ecosystem, users are able to maintain 
  long price exposure to BTC while also accruing a steady 6.25% yield. WBTC is an appealing asset with which to work, 
  because of its growth and network effects. In about 2 years since its creation, its market cap has grown to exceed 
  $3,800,000,000 (at the time of writing). 
  
  The passing of this proposal will create the mWBTC token. All necessary logic to trustlessly create the token will 
  automatically execute if this proposal passes.
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

const createProposalForAddingUsdk = async (governorAlpha, dmmController, usdkAddress) => {
  const addMarketSignature = 'addMarket(address,string,string,uint8,uint256,uint256,uint256)';

  if (!dmmController.contract.methods[addMarketSignature]) {
    throw Error('Invalid addMarketSignature, found ' + addMarketSignature)
  }

  const addMarketCalldata = '0x' + dmmController.contract.methods.addMarket(
    usdkAddress,
    'mUSDK',
    'DMM: USDK',
    18,
    '10000000000', // 0.00000001
    '10000000000', // 0.00000001
    '3000000000000000000000000', // $3mm
  ).encodeABI().substring(10);

  const targets = [dmmController];
  const values = ['0'];
  const signatures = [addMarketSignature]
  const calldatas = [addMarketCalldata];
  const title = 'Add Support for USDK (mUSDK)';
  const description = `
  Proposal Details from the OKEx team:
  
  1. Add USDK on DMM protocol
  2. Support mUSDK on DMM protocol

  
  We propose that the stablecoin [USDK](https://www.okex.com/buy-usdk) should be added to the DMM protocol with a debt 
  ceiling of $3,000,000. With USDK's market cap of ~$30,000,000, this leaves the potential max market cap of mUSDK at 
  about $3,000,000, or 10% of the USDK market cap. We thought this was the best way to manage expectations around both 
  risk and growth. USDK is a stablecoin issued by PrimeTrust and OKLink. Prime Trust is a technology-driven and 
  regulated United States trust company. OKLink Fintech Limited is a wholly owned subsidiary of OKG Technology Holdings 
  Limited (HKEX: 1499).
  
  With the ability to easily scale USDK up, USDK holders would be able to earn a stable 6.25% APY on their USD. 
  Currently, users can easily get USDK on exchanges like OKEx. This will also provide further points of diversification 
  and liquidity, so the DMM DAO can continue to grow.
  
  The passing of this proposal will create the mUSDK token. All necessary logic to trustlessly create the token will 
  automatically execute if this proposal passes.
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
  newOffChainAssetValuatorAddress,
  newOffChainCurrencyValuatorAddress,
  newUnderlyingTokenValuatorAddress,
) => {
  const targets = [dmmController, dmmController, dmmController];
  const values = ['0', '0', '0'];
  const setOffChainAssetValuator = 'setOffChainAssetValuator(address)';
  const setOffChainCurrencyValuator = 'setOffChainCurrencyValuator(address)';
  const setUnderlyingTokenValuator = 'setUnderlyingTokenValuator(address)';
  const signatures = [
    setOffChainAssetValuator,
    setOffChainCurrencyValuator,
    setUnderlyingTokenValuator
  ];

  const setOffChainAssetValuatorCalldata = dmmController.contract.methods
    .setOffChainAssetValuator(newOffChainAssetValuatorAddress).encodeABI().substring(10);

  const setOffChainCurrencyValuatorCalldata = dmmController.contract.methods
    .setOffChainCurrencyValuator(newOffChainCurrencyValuatorAddress).encodeABI().substring(10);

  const setUnderlyingTokenValuatorCalldata = dmmController.contract.methods
    .setUnderlyingTokenValuator(newUnderlyingTokenValuatorAddress).encodeABI().substring(10);

  const calldatas = [
    setOffChainAssetValuatorCalldata,
    setOffChainCurrencyValuatorCalldata,
    setUnderlyingTokenValuatorCalldata
  ];

  const title = 'Upgrade the DMM Ecosystem Chainlink Oracles';
  const description = `
  The DMM Ecosystem Controller needs to be updated to support new functionality that will be needed as we onboard the 
  first principals and affiliates into the ecosystem. This vote strictly centers around updating the off-chain asset 
  valuator, currency valuator, and token valuator. Each of the prior needed an upgrade for one of two reasons: 
  
  1. Chainlink is updating its oracles to point to new contract addresses (which requires the DMM DAO to do the same)
  2. We needed to add the ability to partition funds and permissions depending on asset introducer IDs - this is 
  essential for the DMM ecosystem's growth and transparently displaying the ecosystem's health.
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
      throw Error(`Could not verify ${target} at index ${index}`)
    }
  })

  calldatas = calldatas.map((_, index) => {
    const target = targets[index]
    if (target.contract) {
      if (!calldatas[index].startsWith('0x')) {
        console.warn(`Appending 0x to calldata at ${index} and signature ${signatures[index]}`)
        calldatas[index] = '0x' + calldatas[index];
      }

      if (target.contract.methods[calldatas[index].substring(0, 10).toLowerCase()]) {
        console.warn(`Removing method ID from at index ${index} and signature ${signatures[index]}`)
        return `0x${calldatas[index].substring(10)}`;
      } else {
        return calldatas[index];
      }
    } else {
      throw `Could not verify ${target} at index ${index}`
    }
  });

  const actualAbi = governorAlpha.contract.methods.propose(
    targets.map(target => target.address),
    values,
    signatures,
    calldatas,
    title,
    description
  ).encodeABI();

  console.log(`createGovernanceProposal at ${governorAlpha.address} `, actualAbi);

  // const types = ['address[]', 'uint[]', 'string[]', 'bytes[]', 'string', 'string'];
  // const decoded = new Web3(process.env.PROVIDER).eth.abi.decodeParameters(types, actualAbi);
  // console.log('decoded ', decoded);
};

module.exports = {
  createProposalForYieldFarming,
  createProposalForUpgradingController,
  createProposalForAddingWbtc,
  createProposalForAddingUsdk,
  createProposalForAddingUsdt,
  createProposalForDryRun,
  createGovernanceProposal,
};