const provider = process.env.PROVIDER ? process.env.PROVIDER : new Error("NO PROVIDER GIVEN");
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {BN} = require('ethereumjs-util');
const {callContract, deployContract} = require('./ContractUtils');

const loader = setupLoader({provider: provider, defaultGasPrice: 8e9});

const web3 = new Web3(provider);
const defaultGasPrice = 8e9;

exports.defaultGasPrice = defaultGasPrice;
exports.web3 = web3;

const main = async () => {
  const privateKey = process.env.DEPLOYER;
  const account = web3.eth.accounts.privateKeyToAccount('0x' + privateKey);
  web3.eth.accounts.wallet.add(account);
  web3.eth.defaultAccount = account.address;
  const deployer = account.address;

  const wethAddress = "0x444DFd30CC223205269fDC249D8439EF4fF6109C";

  const DelayedOwner = loader.truffle.fromArtifact('DelayedOwner');
  const DmmController = loader.truffle.fromArtifact('DmmController');
  const DmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory');
  const DmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory');
  const DmmToken = loader.truffle.fromArtifact('DmmToken');
  const ERC20Mock = loader.truffle.fromArtifact('ERC20Mock');

  const delayedOwner = await DelayedOwner.at("0x9037E67a050F84362Bfc2baA95b006688FF7AB26");
  const dmmController = await DmmController.at("0x07e6f395Ff9CbA9FB48Be5e5031FD76d02634af2");
  const daiMock = await ERC20Mock.at("0xa020c81602fbB8031b400C0d033fE111CeBdDd93");

  const gnosisSafeAddress = "0x0323cE501DD42Ed46a409D86e4EB6a9745FCA9EC";

  await adminDepositFunds(delayedOwner, dmmController, gnosisSafeAddress);
  await adminWithdrawFunds(delayedOwner, dmmController, gnosisSafeAddress);
  await executeDelayedTransaction(delayedOwner, new BN(3));
  await executeDelayedTransaction(delayedOwner, new BN(4));

  // await claimOwnershipForDelayedOwner(delayedOwner);
  // await approveController(daiMock, dmmController, new BN(2).pow(new BN(255)));
  // await setBalance(daiMock, gnosisSafeAddress, new BN('2400000000000000000000'));
  // await getOffChainAssetsValue(delayedOwner);

  await addMarket(
    dmmController,
    delayedOwner,
    "0xa020c81602fbB8031b400C0d033fE111CeBdDd93",
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
    "0x500079e692360452c24014C0b7258C04228038FF",
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
    "0x444DFd30CC223205269fDC249D8439EF4fF6109C",
    "mETH",
    "DMM: ETH",
    18,
    '10000000000',
    '10000000000',
    '20000000000000000000000', // 20,000 ETH
  );

  await encodeDmmEtherConstructor(
    web3,
    "0x444DFd30CC223205269fDC249D8439EF4fF6109C",
    "mETH",
    "DMM: ETH",
    18,
    '10000000000',
    '10000000000',
    '20000000000000000000000', // 20,000 ETH
  );
  await encodeDmmTokenConstructor(
    web3,
    "mUSDC",
    "DMM: USDC",
    6,
    '1',
    '1',
    '5000000000000',
  )
};

const encodeDmmTokenConstructor = async (web3, symbol, name, decimals, minMint, minRedeem, totalSupply) => {
  const params = web3.eth.abi.encodeParameters(
    ['string', 'string', 'uint8', 'uint', 'uint', 'uint'],
    [symbol, name, decimals, minMint, minRedeem, totalSupply.toString()],
  );

  console.log(`DmmToken Constructor `, params)
};

const encodeDmmEtherConstructor = async (web3, wethAddress, symbol, name, decimals, minMint, minRedeem, totalSupply) => {
  const params = web3.eth.abi.encodeParameters(
    ['address', 'string', 'string', 'uint8', 'uint', 'uint', 'uint'],
    [wethAddress, symbol, name, decimals, minMint, minRedeem, totalSupply.toString()],
  );

  console.log(`DmmEther Constructor `, params)
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
  const actualAbi = token.contract.methods.approve(
    controller.address,
    amount.toString(),
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

const adminDepositFunds = async (delayedOwner, controller, gnosisSafeAddress) => {
  const innerAbi = controller.contract.methods.adminDepositFunds(gnosisSafeAddress, new BN(1).toString(), _2000).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    controller.address,
    innerAbi,
  ).encodeABI();

  console.log("adminDepositFunds: ", actualAbi);
};

const adminWithdrawFunds = async (delayedOwner, controller, gnosisSafeAddress) => {
  const innerAbi = controller.contract.methods.adminWithdrawFunds(gnosisSafeAddress, new BN(1).toString(), _2000).encodeABI();

  const actualAbi = delayedOwner.contract.methods.transact(
    controller.address,
    innerAbi,
  ).encodeABI();

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