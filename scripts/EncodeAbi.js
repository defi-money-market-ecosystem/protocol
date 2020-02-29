const provider = process.env.PROVIDER ? process.env.PROVIDER : new Error("NO PROVIDER GIVEN");
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {BN, MAX_INTEGER} = require('ethereumjs-util');
const {callContract, deployContract} = require('./ContractUtils');

const loader = setupLoader({provider: provider, defaultGasPrice: 8e9});

const web3 = new Web3(provider);
const defaultGasPrice = 8e9;

exports.defaultGasPrice = defaultGasPrice;
exports.web3 = web3;

const daiAddress = "0xCc64268E6c264399706Cc2a882fd59F8e32405bd";
const usdcAddress = "0xB7Dfe2fd0401e8b0215Ff37fC9E6cb6CD7A0F24B";
const wethAddress = "0x64D0C3E5674A5730bf14994842516e23135CaC9F";

const dmmControllerAddress = "0x1487177063c2808e628b9D917e011cD8629E1E01";
const delayedOwnerAddress = "0x3c68dC440cd3920735c96F924a71a6512dA8585B";

const gnosisSafeAddress = "0x0323cE501DD42Ed46a409D86e4EB6a9745FCA9EC";

const main = async () => {
  const privateKey = process.env.DEPLOYER;
  const account = web3.eth.accounts.privateKeyToAccount('0x' + privateKey);
  web3.eth.accounts.wallet.add(account);
  web3.eth.defaultAccount = account.address;
  const deployer = account.address;

  const wethAddress = "0x64D0C3E5674A5730bf14994842516e23135CaC9F";

  const DelayedOwner = loader.truffle.fromArtifact('DelayedOwner');
  const DmmController = loader.truffle.fromArtifact('DmmController');
  const DmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory');
  const DmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory');
  const DmmToken = loader.truffle.fromArtifact('DmmToken');
  const ERC20Mock = loader.truffle.fromArtifact('ERC20Mock');

  const delayedOwner = await DelayedOwner.at(delayedOwnerAddress);
  const dmmController = await DmmController.at(dmmControllerAddress);
  const daiMock = await ERC20Mock.at(daiAddress);
  const usdcMock = await ERC20Mock.at(usdcAddress);
  const wethMock = await ERC20Mock.at(wethAddress);

  await claimOwnershipForDelayedOwner(delayedOwner);
  await adminDepositFunds(delayedOwner, dmmController);
  await adminWithdrawFunds(delayedOwner, dmmController);
  await executeDelayedTransaction(delayedOwner, new BN(0));
  await executeDelayedTransaction(delayedOwner, new BN(1));
  await executeDelayedTransaction(delayedOwner, new BN(2));
  await executeDelayedTransaction(delayedOwner, new BN(3));

  // await claimOwnershipForDelayedOwner(delayedOwner);
  // await approveController(daiMock, dmmController, new BN(2).pow(new BN(255)));
  // await setBalance(daiMock, gnosisSafeAddress, new BN('2400000000000000000000'));
  // await getOffChainAssetsValue(delayedOwner);

  await sendTokensToRecipient(daiMock, '0x3c68dC440cd3920735c96F924a71a6512dA8585B', new BN("2400000000000000000000"));
  await approveTokenForDelayedOwner(dmmController, delayedOwner, daiMock);

  await addMarket(
    dmmController,
    delayedOwner,
    daiAddress,
    "mDAI",
    "DMM: DAI",
    18,
    '10000000000',
    '10000000000',
    '5000000000000000000000000',
  );

  await addMarket(
    dmmController,
    delayedOwner,
    usdcAddress,
    "mUSDC",
    "DMM: USDC",
    6,
    '1',
    '1',
    '5000000000000',
  );

  await addMarket(
    dmmController,
    delayedOwner,
    wethAddress,
    "mETH",
    "DMM: ETH",
    18,
    '10000000000',
    '10000000000',
    '20000000000000000000000', // 20,000 ETH
  );

  // We don't need this for verifying the contracts on Etherscan. Instead, just take the constructor from the "what we
  // expected" portion of the compiled output during verification.
  // await encodeDmmEtherConstructor(
  //   web3,
  //   wethAddress,
  //   "mETH",
  //   "DMM: ETH",
  //   18,
  //   '10000000000',
  //   '10000000000',
  //   '20000000000000000000000', // 20,000 ETH
  // );
  // await encodeDmmTokenConstructor(
  //   web3,
  //   "mDAI",
  //   "DMM: DAI",
  //   18,
  //   '10000000000',
  //   '10000000000',
  //   '5000000000000000000000000',
  // );
  // await encodeDmmTokenConstructor(
  //   web3,
  //   "mUSDC",
  //   "DMM: USDC",
  //   6,
  //   '1',
  //   '1',
  //   '5000000000000',
  // );
};

const encodeDmmTokenConstructor = async (web3, symbol, name, decimals, minMint, minRedeem, totalSupply) => {
  const params = web3.eth.abi.encodeParameters(
    ['string', 'string', 'uint8', 'uint', 'uint', 'uint'],
    [symbol, name, decimals, minMint, minRedeem, totalSupply.toString()],
  );

  console.log(`DmmToken Constructor for ${symbol}: `, params)
};

// 00000000000000000000000064d0c3e5674a5730bf14994842516e23135cac9f00000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000002540be40000000000000000000000000000000000000000000000000000000002540be40000000000000000000000000000000000000000000000043c33c19375648000000000000000000000000000001487177063c2808e628b9d917e011cd8629e1e0100000000000000000000000000000000000000000000000000000000000000046d455448000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008444d4d3a20455448000000000000000000000000000000000000000000000000
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

const approveController = async (token, controller, amount) => {
  const innerAbi = token.contract.methods.approve(
    controller.address,
    amount.toString(),
  ).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    controller.address,
    innerAbi,
  ).encodeABI();

  console.log("approveController: ", actualAbi);
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

  console.log(`transfer ${token.address}: `, actualAbi);
};

const sendTokensFromDelayedOwnerToRecipient = async (token, delayedOwner, recipient, amount) => {
  const innerAbi = token.contract.methods.transfer(recipient, amount.toString()).encodeABI();
  const actualAbi = delayedOwner.contract.methods.transact(token.address, innerAbi);

  console.log(`transfer ${token.address}: `, actualAbi);
};

const adminDepositFunds = async (delayedOwner, controller) => {
  const innerAbi = controller.contract.methods.adminDepositFunds(new BN(1).toString(), _2000).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    controller.address,
    innerAbi,
  ).encodeABI();

  console.log("adminDepositFunds: ", actualAbi);
};

const adminWithdrawFunds = async (delayedOwner, controller) => {
  const innerAbi = controller.contract.methods.adminWithdrawFunds(new BN(1).toString(), _2000).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(controller.address, innerAbi,).encodeABI();

  console.log("adminWithdrawFunds: ", actualAbi);
};

const executeDelayedTransaction = async (delayedOwner, transactionId) => {
  const actualAbi = delayedOwner.contract.methods.executeTransaction(
    transactionId.toString()
  ).encodeABI();

  console.log(`delayedTransaction with ID ${transactionId.toString()}: `, actualAbi);
};

main().catch(error => {
  console.error("Error ", error);
});