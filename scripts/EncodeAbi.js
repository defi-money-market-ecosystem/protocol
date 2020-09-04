const {throwError} = require('./GeneralUtils');
const provider = process.env.PROVIDER ? process.env.PROVIDER : throwError("NO PROVIDER GIVEN");
const Web3 = require('web3');
const {setupLoader} = require('@openzeppelin/contract-loader');
const {BN, MAX_INTEGER} = require('ethereumjs-util');
const {callContract, deployContract} = require('./ContractUtils');
const {createProposalForYieldFarming} = require('./encode_abi/EncodeGovernanceProposalAbi')
const {approveGloballyTrustedProxy} = require('./encode_abi/EncodeFarming')

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
const mUsdtAddress = "0x84d4AfE150dA7Ea1165B9e45Ff8Ee4798d7C38DA";
const mWethAddress = "0xdF9307DFf0a1B57660F60f9457D32027a55ca0B2";

const delayedOwnerAddress = "0x9E97Ee8631dA9e96bC36a6bF39d332C38d9834DD";
const dmgTokenAddress = "0xEd91879919B71bB6905f23af0A68d231EcF87b14";
const yieldFarmingAddress = "0x502e90e092Cd08e6630e8E1cE426fC6d8ADb3975";
const yieldFarmingRouterAddress = "0x85455Fc1428Ceee0072309f87a227D53783ba6a8";
const dmmControllerAddress = "0x4CB120Dd1D33C9A3De8Bc15620C7Cd43418d77E2";
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
  const account = web3.eth.accounts.privateKeyToAccount('0x' + process.env.DEPLOYER);
  web3.eth.accounts.wallet.add(account);
  web3.eth.defaultAccount = account.address;
  const deployerAddress = account.address;

  const DelayedOwner = loader.truffle.fromArtifact('DelayedOwner');
  const DMGToken = loader.truffle.fromArtifact('DMGToken');
  const DMGYieldFarmingV1 = loader.truffle.fromArtifact('DMGYieldFarmingV1');
  const DmmController = loader.truffle.fromArtifact('DmmController');
  const DmmTokenFactory = loader.truffle.fromArtifact('DmmTokenFactory');
  const DmmEtherFactory = loader.truffle.fromArtifact('DmmEtherFactory');
  const DmmToken = loader.truffle.fromArtifact('DmmToken');
  const ERC20 = loader.truffle.fromArtifact('ERC20');
  const GovernorAlpha = loader.truffle.fromArtifact('GovernorAlpha');
  const OffChainAssetValuatorImplV1 = loader.truffle.fromArtifact('OffChainAssetValuatorImplV1');

  const dmg = await DMGToken.at(dmgTokenAddress);
  const delayedOwner = await DelayedOwner.at(delayedOwnerAddress);
  const dmmController = await DmmController.at(dmmControllerAddress);
  const newDmmController = await DmmController.at(newDmmControllerAddress);
  const governorAlpha = await GovernorAlpha.at(governorAlphaAddress);
  const offChainAssetValuatorImplV1 = await OffChainAssetValuatorImplV1.at(offChainAssetValuatorImplV1Address);
  const yieldFarming = await DMGYieldFarmingV1.at(yieldFarmingAddress);

  const dai = await ERC20.at(daiAddress);
  const link = await ERC20.at(linkAddress);
  const usdc = await ERC20.at(usdcAddress);
  const usdt = await ERC20.at(usdtAddress);
  const weth = await ERC20.at(wethAddress);

  const oneWei = new BN('1000000000000000000');
  const targetDurationDays = new BN('30');
  const maxDebtCeiling = new BN('15000000').mul(new BN('2'));
  const rewardAmountWei = new BN('1000000').mul(oneWei);


  // const farmSeasonAmount = new BN('6430041152');
  // const farmSeasonAmount = new BN('12860082304');
  await approveGloballyTrustedProxy(yieldFarming, yieldFarmingRouterAddress, true);
  console.log('--------------------------------------------------')
  await createProposalForYieldFarming(governorAlpha, gnosisSafeAddress, dmg, deployerAddress, governorTimelockAddress, yieldFarming, rewardAmountWei, targetDurationDays, maxDebtCeiling);

  // const _1000_DAI = new BN('1000000000000000000000');
  // const usdcAmount = new BN('5929500000');
  // await adminWithdrawFunds(delayedOwner, dmmController, daiTokenId, _1000_DAI);
  // await adminWithdrawFunds(delayedOwner, dmmController, usdcTokenId, new BN('300000000000'));
  // await adminDepositFunds(delayedOwner, dmmController, usdcTokenId, usdcAmount);

  // await sendTokensFromDelayedOwnerToRecipient(dai, delayedOwner, gnosisSafeAddress, _1000_DAI);
  // await sendTokensFromDelayedOwnerToRecipient(usdc, delayedOwner, gnosisSafeAddress, new BN('300000000000'));

  // await decreaseTotalSupply(delayedOwner, dmmController, wethTokenId, new BN('5000000000000000000000'));

  // await transferOwnership(newDmmController, governorTimelockAddress);
  // await createProposalForUpgradingController(governorAlpha, dmmController, usdt, newDmmController);

  // await executeDelayedTransaction(delayedOwner, new BN(18));
  //
  // await pauseEcosystem(delayedOwner, await DmmController.at("0xadcFec14eDD9901ce328D1E3e9211Ac64f774321"));
  //
  // await setOraclePayment(delayedOwner, offChainAssetValuatorImplV1, _1.div(new BN(2)));
  // await setCollateralValueJobId(delayedOwner, offChainAssetValuatorImplV1, jobId);
  // await submitGetOffChainAssetsValueRequest(delayedOwner, offChainAssetValuatorImplV1, oracleAddress);
  //
  // await setOffChainAssetValuator(delayedOwner, dmmController, offChainAssetValuatorImplV1Address);
  // await setUnderlyingTokenValuator(delayedOwner, dmmController, underlyingTokenValuatorImplV3Address);
  // );
};

main().catch(error => {
  console.error("Error ", error);
});