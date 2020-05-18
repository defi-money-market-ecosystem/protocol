const provider = process.env.PROVIDER ? process.env.PROVIDER : new Error("NO PROVIDER GIVEN");
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
const wethAddress = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

const dmmControllerAddress = "0x4CB120Dd1D33C9A3De8Bc15620C7Cd43418d77E2";
const delayedOwnerAddress = "0x9E97Ee8631dA9e96bC36a6bF39d332C38d9834DD";
const gnosisSafeAddress = "0xdd7680B6B2EeC193ce3ECe7129708EE12531BCcF";
const offChainAssetValuatorImplV1Address = "0xAcE9112EfE78D9E5018fd12164D30366cA629Ab4";
const underlyingTokenValuatorImplV2Address = "0x693AA8eAD81D2F88A45e870Fa7E25f84Ca93Ca4d";
const underlyingTokenValuatorImplV3Address = "0xE9390E80D1E9833710412C3a14F6f2f7888aAaE1";

const jobId = '0x11cdfd87ac17f6fc2aea9ca5c77544f33decb571339a31f546c2b6a36a406f15';
const oracleAddress = '0x0563fC575D5219C48E2Dfc20368FA4179cDF320D';

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
  const OffChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1');

  const delayedOwner = await DelayedOwner.at(delayedOwnerAddress);
  const dmmController = await DmmController.at(dmmControllerAddress);
  const offChainAssetValuatorImplV1 = await OffChainAssetValuatorImplV1.at(offChainAssetValuatorImplV1Address);

  const dai = await ERC20.at(daiAddress);
  const link = await ERC20.at(linkAddress);
  const usdc = await ERC20.at(usdcAddress);
  const weth = await ERC20.at(wethAddress);

  // await setTimeToLive(delayedOwner, new BN(3600));
  //
  // await withdrawFromAtm(delayedOwner, offChainAssetValuatorImplV1, linkAddress, gnosisSafeAddress, new BN('8500000000000000000'))
  //
  // await claimOwnershipForDelayedOwner(delayedOwner);

  // await adminDepositFunds(delayedOwner, dmmController, wethTokenId, new BN('14548721724500000000'));

  // const _1000_DAI = new BN('1000000000000000000000');
  // const _1000_USDC = new BN('1000000000');
  // await adminWithdrawFunds(delayedOwner, dmmController, daiTokenId, _1000_DAI);
  // await adminWithdrawFunds(delayedOwner, dmmController, usdcTokenId, _1000_USDC);

  // await sendTokensFromDelayedOwnerToRecipient(dai, delayedOwner, gnosisSafeAddress, _1000_DAI);
  // await sendTokensFromDelayedOwnerToRecipient(usdc, delayedOwner, gnosisSafeAddress, _1000_USDC);

  // 1.5m each
  // await decreaseTotalSupply(delayedOwner, dmmController, daiTokenId, new BN('1500000000000000000000000'));
  // await decreaseTotalSupply(delayedOwner, dmmController, usdcTokenId, new BN('1500000000000'));

  await executeDelayedTransaction(delayedOwner, new BN(10));
  await executeDelayedTransaction(delayedOwner, new BN(11));
  await executeDelayedTransaction(delayedOwner, new BN(12));
  await executeDelayedTransaction(delayedOwner, new BN(13));
  await executeDelayedTransaction(delayedOwner, new BN(14));

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
  //
  // await pauseEcosystem(delayedOwner, await DmmController.at("0xadcFec14eDD9901ce328D1E3e9211Ac64f774321"));
  //
  // await setOraclePayment(delayedOwner, offChainAssetValuatorImplV1, _1.div(new BN(2)));
  // await setCollateralValueJobId(delayedOwner, offChainAssetValuatorImplV1, jobId);
  // await submitGetOffChainAssetsValueRequest(delayedOwner, offChainAssetValuatorImplV1, oracleAddress);
  //
  // await setOffChainAssetValuator(delayedOwner, dmmController, offChainAssetValuatorImplV1Address);
  await setUnderlyingTokenValuator(delayedOwner, dmmController, underlyingTokenValuatorImplV3Address);
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
  //   '20000000000000000000000', // 20,000 ETH
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
  const innerAbi = token.contract.methods.transfer(recipient, amount.toString()).encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(token.address, innerAbi).encodeABI();

  console.log(`transfer token=[${token.address}] from delayed owner to ${recipient}: `, actualAbi);
};

const adminDepositFunds = async (delayedOwner, controller, dmmTokenId, amount) => {
  const innerAbi = controller.contract.methods.adminDepositFunds(dmmTokenId.toString(), amount.toString()).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    controller.address,
    innerAbi,
  ).encodeABI();

  console.log(`adminDepositFunds for ${dmmTokenId.toString()}: `, actualAbi);
};

const adminWithdrawFunds = async (delayedOwner, controller, dmmTokenId, amount) => {
  const innerAbi = controller.contract.methods.adminWithdrawFunds(dmmTokenId.toString(), amount.toString()).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(controller.address, innerAbi,).encodeABI();

  console.log(`adminWithdrawFunds for ${dmmTokenId.toString()}: `, actualAbi);
};

const decreaseTotalSupply = async (delayedOwner, controller, dmmTokenId, amount) => {
  const innerAbi = controller.contract.methods.decreaseTotalSupply(dmmTokenId.toString(), amount.toString()).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(controller.address, innerAbi,).encodeABI();

  console.log(`decreaseTotalSupply for ${dmmTokenId.toString()}: `, actualAbi);
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
  const actualAbi = delayedOwner.contract.methods.transact(offChainAssetValuator.address, innerAbi).encodeABI();

  console.log(`setCollateralValueJobId: `, actualAbi);
};

const submitGetOffChainAssetsValueRequest = async (delayedOwner, offChainAssetValuator, oracleAddress) => {
  const innerAbi = offChainAssetValuator.contract.methods.submitGetOffChainAssetsValueRequest(oracleAddress).encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(offChainAssetValuator.address, innerAbi).encodeABI();

  console.log(`submitGetOffChainAssetsValueRequest: `, actualAbi);
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

  console.log(`changeFunctionDelay with ID ${fnName.toString()}: `, actualAbi);
};

const executeDelayedTransaction = async (delayedOwner, transactionId) => {
  const actualAbi = delayedOwner.contract.methods.executeTransaction(
    transactionId.toString()
  ).encodeABI();

  console.log(`delayedTransaction with ID ${transactionId.toString()}: `, actualAbi);
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