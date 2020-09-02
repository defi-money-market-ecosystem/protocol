const {throwError} = require('./GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError("NO PROVIDER GIVEN");
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {BN, MAX_INTEGER} = require('ethereumjs-util');
const {callContract, deployContract} = require('./ContractUtils');

const loader = setupLoader({provider: provider, defaultGasPrice: 8e9});

const web3 = new Web3(provider);
const defaultGasPrice = 6e9;

exports.defaultGasPrice = defaultGasPrice;
exports.web3 = web3;

const defaultUint = new BN(0).toString();
const defaultAddress = '0x0000000000000000000000000000000000000000';

// TESTNET ADDRESSES
// const daiAddress = "0xCc64268E6c264399706Cc2a882fd59F8e32405bd";
// const usdcAddress = "0xB7Dfe2fd0401e8b0215Ff37fC9E6cb6CD7A0F24B";
// const wethAddress = "0x64D0C3E5674A5730bf14994842516e23135CaC9F";
//
// const dmmControllerAddress = "0x1487177063c2808e628b9D917e011cD8629E1E01";
// const delayedOwnerAddress = "0x3c68dC440cd3920735c96F924a71a6512dA8585B";
// const gnosisSafeAddress = "0x0323cE501DD42Ed46a409D86e4EB6a9745FCA9EC";

// MAINNET ADDRESSES
const daiAddress = "0x6b175474e89094c44da98b954eedeac495271d0f";
const linkAddress = "0x514910771af9ca656af840dff83e8264ecf986ca";
const usdcAddress = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";
const usdtAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
const wethAddress = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

const mDaiAddress = "0x06301057D77D54B6e14c7FafFB11Ffc7Cab4eaa7";
const mUsdcAddress = "0x3564ad35b9E95340E5Ace2D6251dbfC76098669B";
const mUsdtAddress = "";
const mWethAddress = "0xdF9307DFf0a1B57660F60f9457D32027a55ca0B2";

const dmmControllerAddress = "0x4CB120Dd1D33C9A3De8Bc15620C7Cd43418d77E2";
const delayedOwnerAddress = "0x9E97Ee8631dA9e96bC36a6bF39d332C38d9834DD";
const gnosisSafeAddress = "0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF";
const governorAlphaAddress = "0x67Cb2868Ebf965b66d3dC81D0aDd6fd849BCF6D5"
const governorTimelockAddress = "0xE679eBf544A6BE5Cb8747012Ea6B08F04975D264"
const offChainAssetValuatorImplV1Address = "0xAcE9112EfE78D9E5018fd12164D30366cA629Ab4";
const underlyingTokenValuatorImplV2Address = "0x693AA8eAD81D2F88A45e870Fa7E25f84Ca93Ca4d";
const underlyingTokenValuatorImplV3Address = "0x7812e0F5Da2F0917BD9054951415EDFF571964dB";
const underlyingTokenValuatorImplV4Address = "0x0c65c147aAf2DbD5109ba74e36f730D081489B5B";

const newDmmControllerAddress = '0xB07EB3426d742cda9120931e7028d54F9dF34A3e';
const newDmmTokenFactoryAddress = '0x6Ce6C84Fe43Df6A28c209b36179bD84a52CAEEFe';

const jobId = '0x2017ac2b3b5b37d2fbb5fef6193d6eef0cb50a4c6b3796c5b5c44bd1cca83aa0';
const oracleAddress = '0x59bbE8CFC79c76857fE0eC27e67E4957370d72B5';

const functionDelay = new BN('3600'); // Function delay

const _1 = new BN('1000000000000000000');

const daiTokenId = new BN(1);
const usdcTokenId = new BN(2);
const wethTokenId = new BN(3);

const main = async () => {
  const privateKey = process.env.DEPLOYER;
  const account = web3.eth.accounts.privateKeyToAccount('0x' + privateKey);
  web3.eth.accounts.wallet.add(account);
  web3.eth.defaultAccount = account.address;
  const deployer = account.address;

  const DelayedOwner = loader.truffle.fromArtifact('DelayedOwner');
  const DmmController = loader.truffle.fromArtifact('DmmController');
  const DmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory');
  const DmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory');
  const DmmToken = loader.truffle.fromArtifact('DmmToken');
  const ERC20 = loader.truffle.fromArtifact('ERC20');
  const GovernorAlpha = loader.truffle.fromArtifact('GovernorAlpha');
  const OffChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1');

  const delayedOwner = await DelayedOwner.at(delayedOwnerAddress);
  const dmmController = await DmmController.at(dmmControllerAddress);
  const newDmmController = await DmmController.at(newDmmControllerAddress);
  const governorAlpha = await GovernorAlpha.at(governorAlphaAddress);
  const offChainAssetValuatorImplV1 = await OffChainAssetValuatorImplV1.at(offChainAssetValuatorImplV1Address);

  const dai = await ERC20.at(daiAddress);
  const link = await ERC20.at(linkAddress);
  const usdc = await ERC20.at(usdcAddress);
  const usdt = await ERC20.at(usdtAddress);
  const weth = await ERC20.at(wethAddress);

  // await setTimeToLive(delayedOwner, new BN(3600));
  //
  // await withdrawFromAtm(delayedOwner, offChainAssetValuatorImplV1, linkAddress, gnosisSafeAddress, new BN('8500000000000000000'))
  //
  // await claimOwnershipForDelayedOwner(delayedOwner);

  // await adminDepositFunds(delayedOwner, dmmController, wethTokenId, new BN('14548721724500000000'));

  // const _1000_DAI = new BN('1000000000000000000000');
  // const usdcAmount = new BN('5929500000');
  // await adminWithdrawFunds(delayedOwner, dmmController, daiTokenId, _1000_DAI);
  // await adminWithdrawFunds(delayedOwner, dmmController, usdcTokenId, new BN('300000000000'));
  // await adminDepositFunds(delayedOwner, dmmController, usdcTokenId, usdcAmount);

  // await sendTokensFromDelayedOwnerToRecipient(dai, delayedOwner, gnosisSafeAddress, _1000_DAI);
  // await sendTokensFromDelayedOwnerToRecipient(usdc, delayedOwner, gnosisSafeAddress, new BN('300000000000'));

  // 1.5m each
  // await decreaseTotalSupply(delayedOwner, dmmController, daiTokenId, new BN('1500000000000000000000000'));
  // await decreaseTotalSupply(delayedOwner, dmmController, usdcTokenId, new BN('1500000000000'));
  // 5,000
  // await decreaseTotalSupply(delayedOwner, dmmController, wethTokenId, new BN('5000000000000000000000'));

  // await transferOwnership(newDmmController, governorTimelockAddress);
  // await createProposalForUpgradingController(governorAlpha, dmmController, usdt, newDmmController);

  // await executeDelayedTransaction(delayedOwner, new BN(18));
  // await executeDelayedTransaction(delayedOwner, new BN(19));
  // await executeDelayedTransaction(delayedOwner, new BN(20));
  // await executeDelayedTransaction(delayedOwner, new BN(21));
  // await executeDelayedTransaction(delayedOwner, new BN(22));

  // await claimOwnershipForDelayedOwner(delayedOwner);
  //
  // await approveTokenForDelayedOwner(dmmController, delayedOwner, dai);
  // await approveTokenForDelayedOwner(dmmController, delayedOwner, usdc);
  // await approveTokenForDelayedOwner(dmmController, delayedOwner, weth);
  //
  // await addMarket(
  //   dmmController,
  //   delayedOwner,
  //   daiAddress,
  //   "mDAI",
  //   "DMM: DAI",
  //   18,
  //   '10000000000',
  //   '10000000000',
  //   '5000000000000000000000000',
  // );
  //
  // await addMarket(
  //   dmmController,
  //   delayedOwner,
  //   usdcAddress,
  //   "mUSDC",
  //   "DMM: USDC",
  //   6,
  //   '1',
  //   '1',
  //   '5000000000000',
  // );
  //
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.enableMarket(defaultUint),
  //   'enableMarket'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.disableMarket(defaultUint),
  //   'disableMarket'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.setInterestRateInterface(defaultAddress),
  //   'setInterestRateInterface'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.setOffChainAssetValuator(defaultAddress),
  //   'setOffChainAssetValuator'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.setOffChainCurrencyValuator(defaultAddress),
  //   'setOffChainCurrencyValuator'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.setUnderlyingTokenValuator(defaultAddress),
  //   'setUnderlyingTokenValuator'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.setMinCollateralization(defaultUint),
  //   'setMinCollateralization'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.setMinReserveRatio(defaultUint),
  //   'setMinReserveRatio'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.increaseTotalSupply(defaultUint, defaultUint),
  //   'increaseTotalSupply'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.decreaseTotalSupply(defaultUint, defaultUint),
  //   'decreaseTotalSupply'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.adminWithdrawFunds(defaultUint, defaultUint),
  //   'adminWithdrawFunds'
  // );
  // await changeFunctionDelay(
  //   delayedOwner,
  //   dmmControllerAddress,
  //   dmmController.contract.methods.adminDepositFunds(defaultUint, defaultUint),
  //   'adminDepositFunds'
  // );

  // await pauseEcosystem(delayedOwner, await DmmController.at("0xadcFec14eDD9901ce328D1E3e9211Ac64f774321"));
  //
  // await setOraclePayment(delayedOwner, offChainAssetValuatorImplV1, _1.div(new BN(2)));
  await setCollateralValueJobId(delayedOwner, offChainAssetValuatorImplV1, jobId);
  // await submitGetOffChainAssetsValueRequest(delayedOwner, offChainAssetValuatorImplV1, oracleAddress);
  //
  // await setOffChainAssetValuator(delayedOwner, dmmController, offChainAssetValuatorImplV1Address);
  // await setUnderlyingTokenValuator(delayedOwner, dmmController, underlyingTokenValuatorImplV3Address);
  //
  // await addMarket(
  //   dmmController,
  //   delayedOwner,
  //   wethAddress,
  //   "mETH",
  //   "DMM: ETH",
  //   18,
  //   '10000000000',
  //   '10000000000',
  //   '10000000000000000000000', // 20,000 ETH
  // );
};

const encodeDmmTokenConstructor = async (web3, symbol, name, decimals, minMint, minRedeem, totalSupply) => {
  const params = web3.eth.abi.encodeParameters(
    ['string', 'string', 'uint8', 'uint', 'uint', 'uint'],
    [symbol, name, decimals, minMint, minRedeem, totalSupply.toString()],
  );

  console.log(`DmmToken Constructor for ${symbol}: `, params)
};

const encodeDmmEtherConstructor = async (web3, wethAddress, symbol, name, decimals, minMint, minRedeem, totalSupply) => {
  const params = web3.eth.abi.encodeParameters(
    ['address', 'string', 'string', 'uint8', 'uint', 'uint', 'uint'],
    [wethAddress, symbol, name, decimals, minMint, minRedeem, totalSupply.toString()],
  );

  console.log(`DmmEther Constructor `, params)
};

const approveTokenForDelayedOwner = async (dmmController, delayedOwner, underlyingToken) => {
  const innerAbi = underlyingToken.contract.methods.approve(dmmController.address, MAX_INTEGER.toString()).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    underlyingToken.address,
    innerAbi,
  ).encodeABI();

  console.log(`Approval for ${underlyingToken.address}: `, actualAbi)
};

const addMarket = async (dmmController, delayedOwner, underlyingAddress, symbol, name, decimals, minMint, minRedeem, totalSupply) => {
  const innerAbi = dmmController.contract.methods.addMarket(
    underlyingAddress,
    symbol,
    name,
    decimals,
    minMint,
    minRedeem,
    totalSupply.toString(),
  ).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    dmmController.address,
    innerAbi,
  ).encodeABI();

  console.log(`Add market for ${symbol}: `, actualAbi)
};

const setBalance = async (token, recipient, amount) => {
  const actualAbi = token.contract.methods.setBalance(recipient, amount.toString()).encodeABI();
  console.log("setBalance: ", actualAbi);
};

const transferOwnership = async (ownerContract, newOwnerAddress) => {
  const actualABI = ownerContract.contract.methods.transferOwnership(newOwnerAddress).encodeABI();
  console.log(`transferOwnership of ${ownerContract.address} `, actualABI)
}

const claimOwnershipForDelayedOwner = async (delayedOwner) => {
  const innerAbi = delayedOwner.contract.methods.claimOwnership().encodeABI();

  console.log("claimOwnership: ", innerAbi);
};

const getOffChainAssetsValue = async (delayedOwner) => {
  const OffChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1');
  const offChainAssetValuatorImplV1 = await OffChainAssetValuatorImplV1.at("0x681Ba299ee5619DC96f5d87aE0F5B19EAB3Cbe8A");
  const oracleAddress = "0x7AFe1118Ea78C1eae84ca8feE5C65Bc76CcF879e";
  const innerAbi = offChainAssetValuatorImplV1.contract.methods.submitGetOffChainAssetsValueRequest(oracleAddress).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    offChainAssetValuatorImplV1.address,
    innerAbi,
  ).encodeABI();

  console.log("getOffChainAssetsValue: ", actualAbi);
};

const _2000 = new BN('2000000000000000000000').toString();

const sendTokensToRecipient = async (token, recipient, amount) => {
  const actualAbi = token.contract.methods.transfer(recipient, amount.toString()).encodeABI();

  console.log(`transfer to ${recipient} ${token.address}: `, actualAbi);
};

const sendTokensFromDelayedOwnerToRecipient = async (token, delayedOwner, recipient, amount) => {
  const actualAbi = token.contract.methods.transfer(recipient, amount.toString()).encodeABI();

  console.log(`transfer token=[${token.address}] from delayed owner to ${recipient}: `, actualAbi);
};

const adminDepositFunds = async (delayedOwner, controller, dmmTokenId, amount) => {
  const innerAbi = controller.contract.methods.adminDepositFunds(dmmTokenId.toString(), amount.toString()).encodeABI();

  // const actualAbi = delayedOwner.contract.methods.transact(
  //   controller.address,
  //   innerAbi,
  // ).encodeABI();

  // console.log(`adminDepositFunds for ${dmmTokenId.toString()}: `, actualAbi);
  console.log(`adminDepositFunds for ${dmmTokenId.toString()}: `, innerAbi);
};

const adminWithdrawFunds = async (delayedOwner, controller, dmmTokenId, amount) => {
  const innerAbi = controller.contract.methods.adminWithdrawFunds(dmmTokenId.toString(), amount.toString()).encodeABI();

  console.log(`adminWithdrawFunds for ${dmmTokenId.toString()}: `, innerAbi);
};

const decreaseTotalSupply = async (delayedOwner, controller, dmmTokenId, amount) => {
  const innerAbi = controller.contract.methods.decreaseTotalSupply(dmmTokenId.toString(), amount.toString()).encodeABI();

  // const actualAbi = delayedOwner.contract.methods.transact(controller.address, innerAbi,).encodeABI();

  // console.log(`decreaseTotalSupply for ${dmmTokenId.toString()}: `, actualAbi);
  console.log(`decreaseTotalSupply for ${dmmTokenId.toString()}: `, innerAbi);
};

const withdrawFromAtm = async (delayedOwner, atmContract, tokenAddress, recipient, amount) => {
  const innerAbi = atmContract.contract.methods.withdraw(tokenAddress, recipient, amount.toString()).encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(atmContract.address, innerAbi).encodeABI();

  console.log(`withdrawFromAtm for ${tokenAddress.toString()}: `, actualAbi);
};

const pauseEcosystem = async (delayedOwner, controller) => {
  const innerAbi = controller.contract.methods.pause().encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(controller.address, innerAbi).encodeABI();

  console.log(`pauseEcosystem: `, actualAbi);
};

const setOraclePayment = async (delayedOwner, offChainAssetValuator, amount) => {
  const innerAbi = offChainAssetValuator.contract.methods.setOraclePayment(amount.toString()).encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(offChainAssetValuator.address, innerAbi).encodeABI();

  console.log(`setOraclePayment: `, actualAbi);
};

const setCollateralValueJobId = async (delayedOwner, offChainAssetValuator, jobId) => {
  const innerAbi = offChainAssetValuator.contract.methods.setCollateralValueJobId(jobId).encodeABI();

  console.log(`setCollateralValueJobId: `, innerAbi);
};

const submitGetOffChainAssetsValueRequest = async (delayedOwner, offChainAssetValuator, oracleAddress) => {
  const innerAbi = offChainAssetValuator.contract.methods.submitGetOffChainAssetsValueRequest(oracleAddress).encodeABI();

  console.log(`submitGetOffChainAssetsValueRequest: `, offChainAssetValuator.address, innerAbi);
};

const setOffChainAssetValuator = async (delayedOwner, dmmController, offChainAssetValuatorAddress) => {
  const innerAbi = dmmController.contract.methods.setOffChainAssetValuator(offChainAssetValuatorAddress).encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(dmmController.address, innerAbi).encodeABI();

  console.log(`setOffChainAssetValuator: `, actualAbi);
};

const setUnderlyingTokenValuator = async (delayedOwner, dmmController, underlyingTokenValuatorAddress) => {
  const innerAbi = dmmController.contract.methods.setUnderlyingTokenValuator(underlyingTokenValuatorAddress).encodeABI();
  // const actualAbi = delayedOwner.contract.methods.transact(dmmController.address, innerAbi).encodeABI();

  console.log(`setUnderlyingTokenValuator: `, dmmController.address, ' ', innerAbi);
};

const changeFunctionDelay = async (delayedOwner, contractAddress, fnCall, fnName) => {
  const actualAbi = delayedOwner.contract.methods.addDelay(
    contractAddress,
    fnCall.encodeABI().slice(0, 10),
    functionDelay.toString(),
  ).encodeABI();

  // 0000000000000000000000004cb120dd1d33c9a3de8bc15620c7cd43418d77e227c3a77
  // 00000000000000000000000000000000000000000000000000000000000000000000000
  // 00000000000000000000000000000000000000000000000e10

  console.log(`Function selector for ${fnName}: `, fnCall.encodeABI().slice(0, 10));

  console.log(`changeFunctionDelay with ID ${fnName.toString()}: `, actualAbi);
};

const createProposalForUpgradingController = async (governorAlpha, dmmController, usdt, newDmmController) => {
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
    newDmmControllerAddress,
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
  
  The address of the new and verified controller is [${newDmmControllerAddress}](https://etherscan.io/address/${newDmmControllerAddress}).
  
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

const createProposalForAddingUsdt = async (governorAlpha, dmmController) => {
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

const executeDelayedTransaction = async (delayedOwner, transactionId) => {
  const actualAbi = delayedOwner.contract.methods.executeTransaction(
    transactionId.toString()
  ).encodeABI();

  // console.log(`delayedTransaction with ID ${transactionId.toString()}: `, actualAbi);
  console.log(`delayedTransaction with ID ${transactionId.toString()}: `, web3.eth.abi.encodeParameters(['uint'], [transactionId]));
};

const setTimeToLive = async (delayedOwner, secondsBN) => {
  const actualAbi = delayedOwner.contract.methods.setTimeToLive(
    secondsBN.toString()
  ).encodeABI();

  console.log(`setTimeToLive: `, actualAbi);
};

main().catch(error => {
  console.error("Error ", error);
});