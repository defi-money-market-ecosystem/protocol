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
  const targets = [erc20Token, erc20Token, dmgBurner];
  const values = ['0', '0', '0'];
  const transferFromCalldata = erc20Token.contract.methods.transferFrom(
    deployerAddress,
    timelockAddress,
    burnAmountWei.toString(),
  );
  const approveCalldata = erc20Token.contract.methods.approve(
    dmgBurner.address,
    burnAmountWei.toString(),
  ).encodeABI();
  const burnDmgCalldata = dmgBurner.contract.methods.burnDmg(
    erc20Token.address,
    burnAmountWei.toString(),
    erc20Token.address.toLowerCase() === wethAddress.toLowerCase() ? [wethAddress, dmgToken.address] : [erc20Token.address, wethAddress, dmgToken.address],
  ).encodeABI()

  const title = 'Token Burn #1: March 2020 - August 2020'
  const description = `
  The DMM DAO has been running at a surplus since its inception in March of 2020. Today, we would like to propose our 
  first token burn to the community, which will buy DMG from Uniswap using USDC. Then, the purchased DMG will be burned 
  once by invoking DMG's native \`burn\` function. The surplus at which the DAO has been running is 10.99% for each
  month, meaning there is a 4.74% overage. While running at a larger scale, we anticipate there being slightly larger
  barriers in/out of crypto that may slightly eat into the overage. A token burn would mean that this excess amount of 
  interest would be used to purchase DMG tokens that would then be burned, which rewards all DMG token holders by 
  making the token deflationary.In turn, this would lower the circulating supply and increase token demand, creating an 
  incentive for people to HODL DMG tokens.
  
  The following table, shown below, showcases the estimated value of mTokens in circulation for the months of March 
  through August. Then, the amount burned is calculated by multiplying it by the monthly amortization of the burn 
  percentage (which equals 4.74% / 12). The total dollar amount of DMG to be burned is $35,147.
  
  | Month   | Estimated AUM in all mTokens  | Burn Amount   |
  |-------- |------------------------------ |------------:  |
  | March   | $37,222                       | $147          |
  | April   | $188,766                      | $746          |
  | May     | $456,043                      | $1,801        |
  | June    | $1,667,163                    | $6,585        |
  | July    | $3,065,695                    | $12,109       |
  | August  | $3,483,289                    | $13,759       |
  
  This marks an important step forward for the DAO, as we display to all members how important accumulating deposits in
  mTokens is and how it affects the deflationary attributes of DMG. Moreover, we understand that this surplus 
  calculation process is not transparent or trustless enough for certain members of the DAO, who would like to see the 
  entire process done on-chain - we agree! We will be designing a way to leverage the Chainlink Oracle Network to bring 
  this data on-chain on a regular basis, so the burning process can be done in a trust-minimized manner whenever a 
  burn-oriented vote passes.
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