const {createGovernanceProposal} = require('./EncodeGovernanceProposalAbi')

const createProposalForBurningTokens = async (
  governorAlpha,
  erc20Token,
  timelockAddress,
  deployerAddress,
  burnAmountWei,
  dmgBurner,
  wethAddress,
  dmgToken,
) => {
  console.log('deployerAddress ', deployerAddress);
  console.log('governorAlpha ', governorAlpha.address);
  console.log('timelockAddress ', timelockAddress);

  const targets = [erc20Token, erc20Token, dmgBurner];
  const values = ['0', '0', '0'];
  const transferFromCalldata = erc20Token.contract.methods.transferFrom(
    deployerAddress,
    timelockAddress,
    burnAmountWei.toString(),
  ).encodeABI();
  const approveCalldata = erc20Token.contract.methods.approve(
    dmgBurner.address,
    burnAmountWei.toString(),
  ).encodeABI();
  const burnDmgCalldata = dmgBurner.contract.methods.burnDmg(
    erc20Token.address,
    burnAmountWei.toString(),
    erc20Token.address.toLowerCase() === wethAddress.toLowerCase() ? [wethAddress, dmgToken.address] : [erc20Token.address, wethAddress, dmgToken.address],
  ).encodeABI()

  const title = 'Token Burn #3: November 2020 - December 2020'
  const description = `
  As explained in our [first token burn](https://dao.defimoneymarket.com/governance/proposals/7), the DMM DAO has been 
  running at a surplus since its inception in March of 2020. We are proposinng our third token burn to the community, 
  which will buy DMG from Uniswap using USDC. Then, the purchased DMG will be burned by invoking DMG's native \`burn\` 
  function. The surplus at which the DAO has been running is 10.99% for each month, meaning there is a 4.74% overage. A 
  token burn would mean that this excess amount of interest would be used to purchase and burn DMG tokens, which 
  rewards all DMG token holders by making the token deflationary. In turn, this would lower the circulating supply and 
  increase token demand, creating an incentive for people to HODL DMG tokens.
  
  The following table, shown below, showcases the estimated value of mTokens in circulation for the months of September 
  and October. Then, the amount burned is calculated by multiplying it by the monthly amortization of the burn 
  percentage (which equals 4.74% / 12). The total dollar amount of DMG to be burned is $33,168.
  
  | Month      | Estimated AUM in all mTokens &nbsp;&nbsp;&nbsp; | Burn Amount   |
  |:---------- |:----------------------------------------------- |------------:  |
  | November   | $3,979,994                                      | $15,721       |
  | December   | $4,416,887                                      | $17,447       |
  
  `;

  const signatures = [
    'approve(address,uint256)',
    'transferFrom(address,address,uint256)',
    'burnDmg(address,uint256,address[])',
  ];

  const calldatas = [approveCalldata, transferFromCalldata, burnDmgCalldata];

  await createGovernanceProposal(governorAlpha, targets, values, signatures, calldatas, title, description);
};

module.exports = {
  createProposalForBurningTokens: createProposalForBurningTokens,
};