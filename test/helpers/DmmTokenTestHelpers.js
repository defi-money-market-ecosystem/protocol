const {web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
const web3Config = require('@openzeppelin/test-helpers/src/config/web3');
const {
  BN,
  constants,
  expectEvent,
  expectRevert
} = require('@openzeppelin/test-helpers');
const ethereumJsUtil = require('ethereumjs-util');

const _0 = () => new BN('0');
const _1 = () => new BN('1000000000000000000');
const _24 = () => new BN('24000000000000000000');
const _24_5 = () => new BN('24500000000000000000');
const _25 = () => new BN('25000000000000000000');
const _50 = () => new BN('50000000000000000000');
const _75 = () => new BN('75000000000000000000');
const _100 = () => new BN('100000000000000000000');
const _10000 = () => new BN('10000000000000000000000');

const doBeforeEach = async (thisInstance, contracts, web3) => {
  web3Config.getWeb3 = () => web3;

  const DmmBlacklistable = contracts.fromArtifact('DmmBlacklistable');
  const DmmControllerMock = contracts.fromArtifact('DmmControllerMock');
  const DmmToken = contracts.fromArtifact('DmmToken');
  const DmmTokenLibrary = contracts.fromArtifact('DmmTokenLibrary');
  const ERC20Mock = contracts.fromArtifact('ERC20Mock');
  const SafeERC20 = contracts.fromArtifact('SafeERC20');
  const SafeMath = contracts.fromArtifact('SafeMath');

  await ERC20Mock.detectNetwork();
  await DmmToken.detectNetwork();
  await DmmTokenLibrary.detectNetwork();

  const safeERC20 = await SafeERC20.new();
  const safeMath = await SafeMath.new();
  const dmmTokenLibrary = await DmmTokenLibrary.new();

  await ERC20Mock.link("SafeMath", safeMath.address);

  await DmmToken.link("SafeERC20", safeERC20.address);
  await DmmToken.link("SafeMath", safeMath.address);
  await DmmToken.link("DmmTokenLibrary", dmmTokenLibrary.address);

  thisInstance.blacklistable = await DmmBlacklistable.new({from: thisInstance.admin});

  thisInstance.underlyingToken = await ERC20Mock.new({from: thisInstance.admin});
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

  thisInstance.symbol = "dmmDAI";
  thisInstance.name = "DMM: DAI";
  thisInstance.decimals = new BN(18);
  thisInstance.minMintAmount = _1();
  thisInstance.minRedeemAmount = _1();
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

const expectMint = (thisInstance, receipt, recipient, amount) => {
  expectEvent(
    receipt,
    'Mint',
    {
      minter: thisInstance.wallet.address,
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
      dmmToken.mint(amount, {from: user}),
      expectedError
    )
  } else {
    const mintReceipt = await dmmToken.mint(amount, {from: user});
    expectEvent(
      mintReceipt,
      'Mint',
      {minter: user, recipient: user, amount: amount}
    );
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
      {redeemer: user, recipient: user, amount: amount}
    );
  }
};

const pauseEcosystem = async (controller, admin) => {
  expect(await controller.isPaused()).to.equal(false);
  await controller.pause({from: admin});
  expect(await controller.isPaused()).to.equal(true);
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
  thisInstance.interestRate = new BN('62500000000000000');
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
  _1,
  _24,
  _24_5,
  _25,
  _50,
  _75,
  _100,
  _10000,
  doBeforeEach,
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
};