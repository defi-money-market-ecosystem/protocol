const {web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
const web3Config = require('@openzeppelin/test-helpers/src/config/web3');
const {
  BN,
  constants,
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const ethereumJsUtil = require('ethereumjs-util');

const _0 = () => new BN('0');
const _001 = () => new BN('10000000000');
const _00625 = () => new BN('62500000000000000');
const _05 = () => new BN('500000000000000000');
const _1 = () => new BN('1000000000000000000');
const _24 = () => new BN('24000000000000000000');
const _24_99 = () => new BN('24999999999999999999');
const _25 = () => new BN('25000000000000000000');
const _50 = () => new BN('50000000000000000000');
const _75 = () => new BN('75000000000000000000');
const _100 = () => new BN('100000000000000000000');
const _10000 = () => new BN('10000000000000000000000');
const _1000000 = () => new BN('1000000000000000000000000');
const _250000000 = () => new BN('250000000000000000000000000');

const doYieldFarmingBeforeEach = async (thisInstance, contracts, web3) => {
  web3Config.getWeb3 = () => web3;

  const DMGToken = contracts.fromArtifact('DMGToken');
  const DMGYieldFarmingV1 = contracts.fromArtifact('DMGYieldFarmingV1');
  const DMGYieldFarmingProxy = contracts.fromArtifact('DMGYieldFarmingProxy');
  const ERC20Mock = contracts.fromArtifact('ERC20Mock');
  const UnderlyingTokenValuatorMock = contracts.fromArtifact('UnderlyingTokenValuatorMock');

  thisInstance.dmgToken = await DMGToken.new(thisInstance.admin, {from: thisInstance.admin});

  thisInstance.dmmController =

  thisInstance.tokenA = await ERC20Mock.new({from: thisInstance.admin});
  thisInstance.tokenB = await ERC20Mock.new({from: thisInstance.admin});

  thisInstance.allowableTokens = [thisInstance.tokenA.address, thisInstance.tokenB.address];
  thisInstance.underlyingTokens = [thisInstance.tokenA.address, thisInstance.tokenB.address];

  thisInstance.implementation = await DMGYieldFarmingV1.new(
    {from: thisInstance.admin},
  );

  thisInstance.yieldFarming = await DMGYieldFarmingProxy.new(
    thisInstance.implementation.address,
    thisInstance.admin,
    // Begin IMPL initializer
    thisInstance.dmgToken.address,
    thisInstance.admin,
    thisInstance.dmmController.address,
    _1(),
    thisInstance.allowableTokens,
    thisInstance.underlyingTokens,
    [18, 6],
    [new BN('100'), new BN('300')],
  )
};

const doDmgTokenBeforeEach = async (thisInstance, contracts, web3) => {
  web3Config.getWeb3 = () => web3;

  const DMGToken = contracts.fromArtifact('DMGToken');

  thisInstance.dmgToken = await DMGToken.new(thisInstance.admin, {from: thisInstance.admin});
};

const doDmmTokenBeforeEach = async (thisInstance, contracts, web3) => {
  web3Config.getWeb3 = () => web3;

  const DmmBlacklistable = contracts.fromArtifact('DmmBlacklistable');
  const DmmControllerMock = contracts.fromArtifact('DmmControllerMock');
  const DmmToken = contracts.fromArtifact('DmmToken');
  const DmmTokenLibrary = contracts.fromArtifact('DmmTokenLibrary');
  const ERC20Mock = contracts.fromArtifact('ERC20Mock');
  const SafeERC20 = contracts.fromArtifact('SafeERC20');
  const SafeMath = contracts.fromArtifact('SafeMath');

  await Promise.all([ERC20Mock.detectNetwork(), DmmToken.detectNetwork()]);

  const safeERC20 = await SafeERC20.new();
  const safeMath = await SafeMath.new();
  const dmmTokenLibrary = await DmmTokenLibrary.new();

  await Promise.all([
    ERC20Mock.link("SafeMath", safeMath.address),
    DmmToken.link("SafeERC20", safeERC20.address),
    DmmToken.link("SafeMath", safeMath.address),
    DmmToken.link("DmmTokenLibrary", dmmTokenLibrary.address),
  ]);

  thisInstance.blacklistable = await DmmBlacklistable.new({from: thisInstance.admin});

  thisInstance.underlyingToken = await ERC20Mock.new({from: thisInstance.admin});
  thisInstance.dai = thisInstance.underlyingToken;

  thisInstance.interestRate = _0();
  thisInstance.controller = await DmmControllerMock.new(
    thisInstance.blacklistable.address,
    thisInstance.underlyingToken.address,
    thisInstance.interestRate,
    {from: thisInstance.admin}
  );

  const setBalanceReceipt = await thisInstance.underlyingToken.setBalance(thisInstance.user, _10000());
  expectEvent(
    setBalanceReceipt,
    'Transfer'
  );

  thisInstance.symbol = "mDAI";
  thisInstance.name = "DMM: DAI";
  thisInstance.decimals = new BN(18);
  thisInstance.minMintAmount = _001();
  thisInstance.minRedeemAmount = _001();
  thisInstance.totalSupply = _10000();

  thisInstance.contract = await DmmToken.new(
    thisInstance.symbol,
    thisInstance.name,
    thisInstance.decimals,
    thisInstance.minMintAmount,
    thisInstance.minRedeemAmount,
    thisInstance.totalSupply,
    thisInstance.controller.address,
    {from: thisInstance.admin}
  );

  thisInstance.mDAI = thisInstance.contract;
};

const doDmmEtherBeforeEach = async (thisInstance, contracts, web3, lastUser) => {
  web3Config.getWeb3 = () => web3;

  const DmmBlacklistable = contracts.fromArtifact('DmmBlacklistable');
  const DmmControllerMock = contracts.fromArtifact('DmmControllerMock');
  const DmmEther = contracts.fromArtifact('DmmEther');
  const DmmTokenLibrary = contracts.fromArtifact('DmmTokenLibrary');
  const WETHMock = contracts.fromArtifact('WETHMock');
  const SafeERC20 = contracts.fromArtifact('SafeERC20');
  const SafeMath = contracts.fromArtifact('SafeMath');

  await Promise.all([
    WETHMock.detectNetwork(), DmmEther.detectNetwork()
  ]);

  const safeERC20 = await SafeERC20.new();
  const safeMath = await SafeMath.new();
  const dmmTokenLibrary = await DmmTokenLibrary.new();

  await Promise.all([
    WETHMock.link("SafeMath", safeMath.address),
    DmmEther.link("SafeERC20", safeERC20.address),
    DmmEther.link("SafeMath", safeMath.address),
    DmmEther.link("DmmTokenLibrary", dmmTokenLibrary.address),
  ]);

  thisInstance.blacklistable = await DmmBlacklistable.new({from: thisInstance.admin});

  thisInstance.underlyingToken = await WETHMock.new({from: thisInstance.admin});
  thisInstance.interestRate = _0();
  thisInstance.controller = await DmmControllerMock.new(
    thisInstance.blacklistable.address,
    thisInstance.underlyingToken.address,
    thisInstance.interestRate,
    {from: thisInstance.admin}
  );

  const setWethBalanceReceipt = await thisInstance.underlyingToken.setBalance(thisInstance.user, _100());
  expectEvent(
    setWethBalanceReceipt,
    'Transfer'
  );

  const setEthBalanceReceipt = await thisInstance.underlyingToken.deposit({from: lastUser, value: _100()});
  expectEvent(
    setEthBalanceReceipt,
    'Deposit'
  );

  thisInstance.symbol = "mETH";
  thisInstance.name = "DMM: ETH";
  thisInstance.decimals = new BN(18);
  thisInstance.minMintAmount = _001();
  thisInstance.minRedeemAmount = _001();
  thisInstance.totalSupply = _10000();

  thisInstance.contract = await DmmEther.new(
    thisInstance.underlyingToken.address,
    thisInstance.symbol,
    thisInstance.name,
    thisInstance.decimals,
    thisInstance.minMintAmount,
    thisInstance.minRedeemAmount,
    thisInstance.totalSupply,
    thisInstance.controller.address,
    {from: thisInstance.admin}
  );

  thisInstance.mETH = thisInstance.contract;
};

const doDmmControllerBeforeEach = async (thisInstance, contracts, web3) => {
  web3Config.getWeb3 = () => web3;

  const DmmBlacklistable = contracts.fromArtifact('DmmBlacklistable');
  const DmmOffChainAssetValuatorMock = contracts.fromArtifact('DmmOffChainAssetValuatorMock');
  const DmmController = contracts.fromArtifact('DmmController');
  const DmmEtherFactory = contracts.fromArtifact('DmmEtherFactory');
  const DmmTokenFactory = contracts.fromArtifact('DmmTokenFactory');
  const DmmTokenLibrary = contracts.fromArtifact('DmmTokenLibrary');
  const ERC20Mock = contracts.fromArtifact('ERC20Mock');
  const InterestRateImplV1 = contracts.fromArtifact('InterestRateImplV1');
  const OffChainCurrencyValuatorImplV1 = contracts.fromArtifact('OffChainCurrencyValuatorImplV1');
  const SafeERC20 = contracts.fromArtifact('SafeERC20');
  const SafeMath = contracts.fromArtifact('SafeMath');
  const StringHelpers = contracts.fromArtifact('StringHelpers');
  const UnderlyingTokenValuatorImplV4 = contracts.fromArtifact('UnderlyingTokenValuatorImplV4');
  const WETHMock = contracts.fromArtifact('WETHMock');

  await Promise.all(
    [
      ERC20Mock.detectNetwork(),
      DmmController.detectNetwork(),
      DmmEtherFactory.detectNetwork(),
      DmmTokenFactory.detectNetwork(),
      StringHelpers.detectNetwork(),
      UnderlyingTokenValuatorImplV4.detectNetwork(),
    ]
  );

  const safeERC20 = await SafeERC20.new();
  const safeMath = await SafeMath.new();
  const dmmTokenLibrary = await DmmTokenLibrary.new();
  const stringHelpers = await StringHelpers.new();

  await Promise.all(
    [
      ERC20Mock.link('SafeMath', safeMath.address),
      DmmController.link('DmmTokenLibrary', dmmTokenLibrary.address),
      DmmTokenFactory.link('SafeERC20', safeERC20.address),
      DmmTokenFactory.link('SafeMath', safeMath.address),
      DmmTokenFactory.link('DmmTokenLibrary', dmmTokenLibrary.address),
      DmmEtherFactory.link('SafeERC20', safeERC20.address),
      DmmEtherFactory.link('SafeMath', safeMath.address),
      DmmEtherFactory.link('DmmTokenLibrary', dmmTokenLibrary.address),
      UnderlyingTokenValuatorImplV4.link("StringHelpers", stringHelpers.address),
    ]
  );

  thisInstance.dai = await ERC20Mock.new({from: thisInstance.admin});
  thisInstance.usdc = await ERC20Mock.new({from: thisInstance.admin});
  thisInstance.weth = await WETHMock.new({from: thisInstance.admin});

  thisInstance.interestRateInterface = await InterestRateImplV1.new({from: thisInstance.admin});
  thisInstance.offChainAssetValuator = await DmmOffChainAssetValuatorMock.new({from: thisInstance.admin});
  thisInstance.offChainCurrencyValuator = await OffChainCurrencyValuatorImplV1.new({from: thisInstance.admin});
  thisInstance.underlyingTokenValuator = await UnderlyingTokenValuatorImplV4.new(
    thisInstance.dai.address,
    thisInstance.usdc.address,
    {from: thisInstance.admin},
  );

  thisInstance.dmmEtherFactory = await DmmEtherFactory.new(thisInstance.weth.address, {from: thisInstance.admin});
  thisInstance.dmmTokenFactory = await DmmTokenFactory.new({from: thisInstance.admin});
  thisInstance.blacklistable = await DmmBlacklistable.new({from: thisInstance.admin});
  thisInstance.minReserveRatio = _05();
  thisInstance.minCollateralization = _1();

  thisInstance.controller = await DmmController.new(
    thisInstance.admin,
    thisInstance.interestRateInterface.address,
    thisInstance.offChainAssetValuator.address,
    thisInstance.offChainCurrencyValuator.address,
    thisInstance.underlyingTokenValuator.address,
    thisInstance.dmmEtherFactory.address,
    thisInstance.dmmTokenFactory.address,
    thisInstance.blacklistable.address,
    thisInstance.minCollateralization,
    thisInstance.minReserveRatio,
    thisInstance.weth.address,
    {from: thisInstance.admin}
  );

  await thisInstance.dmmEtherFactory.transferOwnership(thisInstance.controller.address, {from: thisInstance.admin});
  await thisInstance.dmmTokenFactory.transferOwnership(thisInstance.controller.address, {from: thisInstance.admin});

  const setDaiBalanceReceipt = await thisInstance.dai.setBalance(thisInstance.user, _10000());
  expectEvent(
    setDaiBalanceReceipt,
    'Transfer'
  );

  const setUsdcBalanceReceipt = await thisInstance.usdc.setBalance(thisInstance.user, _10000());
  expectEvent(
    setUsdcBalanceReceipt,
    'Transfer'
  );
};

const encodeHashAndSign = async (thisInstance, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient) => {
  const domainSeparator = await thisInstance.contract.domainSeparator();
  const messageHash = web3.utils.sha3(
    web3.eth.abi.encodeParameters(
      [
        'bytes32',
        'address',
        'address',
        'uint',
        'uint',
        'uint',
        'uint',
        'address',
      ],
      [
        typeHash,
        thisInstance.wallet.address,
        recipient,
        nonce.toString(),
        expiry.toString(),
        amount.toString(),
        feeAmount.toString(),
        feeRecipient,
      ]
    )
  );
  const digest = web3.utils.soliditySha3('\x19\x01', domainSeparator, messageHash);
  return signMessage(thisInstance, digest);
};

const encodePermitHashAndSign = async (thisInstance, typeHash, recipient, nonce, expiry, allowed, feeAmount, feeRecipient) => {
  const domainSeparator = await thisInstance.contract.domainSeparator();
  const messageHash = web3.utils.sha3(
    web3.eth.abi.encodeParameters(
      [
        'bytes32',
        'address',
        'address',
        'uint',
        'uint',
        'bool',
        'uint',
        'address',
      ],
      [
        typeHash,
        thisInstance.wallet.address,
        recipient,
        nonce.toString(),
        expiry.toString(),
        allowed,
        feeAmount.toString(),
        feeRecipient,
      ]
    )
  );
  const digest = web3.utils.soliditySha3('\x19\x01', domainSeparator, messageHash);
  return signMessage(thisInstance, digest);
};

const expectMint = (thisInstance, receipt, minter, recipient, amount) => {
  expectEvent(
    receipt,
    'Mint',
    {
      minter: minter ? minter : thisInstance.wallet.address,
      recipient: recipient,
      amount: amount ? amount : _25(),
    }
  );
};

const expectOffChainRequestValidated = (thisInstance, receipt, feeRecipient, feeAmount, nonce, expiry) => {
  expectEvent(
    receipt,
    'OffChainRequestValidated',
    {
      owner: thisInstance.wallet.address,
      feeRecipient: feeRecipient,
      feeAmount: feeAmount,
      nonce: nonce,
      expiry: expiry,
    },
  );
};

const expectRedeem = (thisInstance, receipt, recipient, amount) => {
  expectEvent(
    receipt,
    'Redeem',
    {
      redeemer: thisInstance.wallet.address,
      recipient: recipient,
      amount: amount ? amount : _25(),
    }
  );
};

const expectApprove = (thisInstance, receipt, recipient, allowed) => {
  expectEvent(
    receipt,
    'Approval',
    {
      owner: thisInstance.wallet.address,
      spender: recipient,
      value: allowed ? constants.MAX_UINT256 : _0(),
    }
  );
};

const expectTransfer = (thisInstance, receipt, recipient, amount) => {
  expectEvent(
    receipt,
    'Transfer',
    {
      from: thisInstance.wallet.address,
      to: recipient,
      value: amount ? amount : _25(),
    }
  );
};

const keccak256 = (...args) => {
  args = args.map(arg => {
    if (typeof arg === 'string') {
      if (arg.substring(0, 2) === '0x') {
        return arg.slice(2)
      } else {
        return web3.utils.toHex(arg).slice(2)
      }
    }

    if (typeof arg === 'number') {
      return web3.utils.leftPad((arg).toString(16), 64, 0)
    } else {
      return ''
    }
  });

  args = args.join('');

  return web3.utils.sha3(args, {encoding: 'hex'})
};

const mint = async (underlyingToken, dmmToken, user, amount, expectedError) => {
  const approvalReceipt = await underlyingToken.approve(dmmToken.address, constants.MAX_UINT256, {from: user});
  expectEvent(
    approvalReceipt,
    'Approval',
    {owner: user, spender: dmmToken.address, value: constants.MAX_UINT256}
  );

  if (expectedError) {
    await expectRevert.unspecified(
      dmmToken.contract.methods.mint(amount, {from: user}),
      expectedError
    );
    return _0();
  } else {
    const mintReceipt = await dmmToken.mint(amount, {from: user});
    expectEvent(
      mintReceipt,
      'Mint',
      {minter: user, recipient: user}
    );
    return mintReceipt.logs.filter(value => value.event === 'Mint')[0].args['amount'];
  }
};

const redeem = async (dmmToken, user, amount, expectedError) => {
  const approvalReceipt = await dmmToken.approve(dmmToken.address, constants.MAX_UINT256, {from: user});
  expectEvent(
    approvalReceipt,
    'Approval',
    {owner: user, spender: dmmToken.address, value: constants.MAX_UINT256}
  );

  if (expectedError) {
    await expectRevert(
      dmmToken.redeem(amount, {from: user}),
      expectedError
    )
  } else {
    const redemptionReceipt = await dmmToken.redeem(amount, {from: user});
    expectEvent(
      redemptionReceipt,
      'Redeem',
      {redeemer: user, recipient: user}
    );
  }
};

const pauseEcosystem = async (controller, admin) => {
  expect(await controller.paused()).to.equal(false);
  await controller.pause({from: admin});
  expect(await controller.paused()).to.equal(true);
};

const disableMarkets = async (controller, admin) => {
  await controller.setMarketsEnabled(false, {from: admin});
};

const blacklistUser = async (blacklistable, user, admin) => {
  const receipt = await blacklistable.blacklist(user, {from: admin});
  expectEvent(
    receipt,
    'Blacklisted',
    {account: user}
  );
};

const setBalanceFor = async (token, address, amount) => {
  const receipt = await token.setBalance(address, amount);
  expectEvent(receipt, 'Transfer')
};

const setApproval = async (token, owner, spender) => {
  const receipt = await token.approve(spender, constants.MAX_UINT256, {from: owner});
  expectEvent(
    receipt,
    'Approval',
    {owner: owner, spender: spender, value: constants.MAX_UINT256}
  )
};

const setRealInterestRateOnController = async (thisInstance) => {
  thisInstance.interestRate = _00625();
  await thisInstance.controller.setInterestRate(thisInstance.interestRate);
};

const setupWallet = async (thisInstance, user) => {
  await thisInstance.send.ether(user, thisInstance.wallet.address, _1());
  await setBalanceFor(thisInstance.underlyingToken, thisInstance.wallet.address, _10000());
  await thisInstance.underlyingToken.approve(
    thisInstance.contract.address,
    constants.MAX_UINT256,
    {from: thisInstance.wallet.address},
  );
};

const signMessage = async (thisInstance, digest) => {
  const digestBuffer = Buffer.from(digest.replace('0x', ''), 'hex');
  const privateKeyBuffer = Buffer.from(thisInstance.wallet.privateKey.replace('0x', ''), 'hex');
  return ethereumJsUtil.ecsign(digestBuffer, privateKeyBuffer)
};

module.exports = {
  _0,
  _001,
  _00625,
  _05,
  _1,
  _24,
  _24_99,
  _25,
  _50,
  _75,
  _100,
  _10000,
  _1000000,
  _250000000,
  doDmgTokenBeforeEach,
  doDmmControllerBeforeEach,
  doDmmEtherBeforeEach,
  doDmmTokenBeforeEach,
  doYieldFarmingBeforeEach,
  encodeHashAndSign,
  encodePermitHashAndSign,
  expectApprove,
  expectMint,
  expectOffChainRequestValidated,
  expectRedeem,
  expectTransfer,
  keccak256,
  mint,
  redeem,
  pauseEcosystem,
  disableMarkets,
  blacklistUser,
  setBalanceFor,
  setApproval,
  setRealInterestRateOnController,
  setupWallet,
  signMessage,
};