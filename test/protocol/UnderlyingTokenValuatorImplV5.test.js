const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectEvent, expectRevert} = require('@openzeppelin/test-helpers');
const {snapshotChain, resetChain} = require('../helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [owner, guardian, other] = accounts;

// Create a contract object from a compilation artifact
const ERC20Mock = contract.fromArtifact('ERC20Mock');
const WETHMock = contract.fromArtifact('WETHMock');
const DaiUsdAggregatorMock = contract.fromArtifact('DaiUsdAggregatorMock');
const EthUsdAggregatorMock = contract.fromArtifact('EthUsdAggregatorMockV2');
const UsdcEthAggregatorMock = contract.fromArtifact('UsdcEthAggregatorMock');
const UsdtEthAggregatorMock = contract.fromArtifact('UsdtEthAggregatorMock');
const SafeMath = contract.fromArtifact('SafeMath');
const StringHelpers = contract.fromArtifact('StringHelpers');
const UnderlyingTokenValuatorImplV5 = contract.fromArtifact('UnderlyingTokenValuatorImplV5');
const UnderlyingTokenValuatorProxy = contract.fromArtifact('UnderlyingTokenValuatorProxy');

describe('UnderlyingTokenValuatorImplV5', () => {
  let valuator = null;
  let dai = null;
  let usdc = null;
  let usdt = null;
  let weth = null;
  let daiUsdAggregator = null;
  let ethUsdAggregator = null;
  let usdcEthAggregator = null;
  let usdtEthAggregator = null;
  let snapshotId;

  const newTokenAddress = web3.utils.toChecksumAddress('0x1000000000000000000000000000000000000000');
  const newAggregatorAddress = web3.utils.toChecksumAddress('0x0000000000000000000000000000000000000001');
  const newQuoteSymbol = web3.utils.toChecksumAddress('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF');

  before(async () => {
    await ERC20Mock.detectNetwork();
    const safeMath = await SafeMath.new();

    ERC20Mock.link("SafeMath", safeMath.address);

    dai = await ERC20Mock.new();
    usdc = await ERC20Mock.new();
    usdt = await ERC20Mock.new();
    weth = await WETHMock.new();

    const stringHelpers = await StringHelpers.new();

    daiUsdAggregator = await DaiUsdAggregatorMock.new();
    ethUsdAggregator = await EthUsdAggregatorMock.new();
    usdcEthAggregator = await UsdcEthAggregatorMock.new();
    usdtEthAggregator = await UsdtEthAggregatorMock.new();

    await UnderlyingTokenValuatorImplV5.detectNetwork();
    UnderlyingTokenValuatorImplV5.link("StringHelpers", stringHelpers.address);

    const implementation = await UnderlyingTokenValuatorImplV5.new({from: owner});
    valuator = await UnderlyingTokenValuatorProxy.new(
      implementation.address,
      guardian,
      owner,
      guardian,
      weth.address,
      [dai.address, usdc.address, usdt.address, weth.address],
      [daiUsdAggregator.address, usdcEthAggregator.address, usdtEthAggregator.address, ethUsdAggregator.address],
      [constants.ZERO_ADDRESS, weth.address, weth.address, constants.ZERO_ADDRESS],
      {from: owner}
    );

    console.log('valuator ', (await web3.eth.getTransactionReceipt(valuator.transactionHash)).gasUsed.toString())

    valuator = contract.fromArtifact('UnderlyingTokenValuatorImplV5', valuator.address);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('should get token properties', async () => {
    expect(await valuator.getAggregatorByToken(dai.address)).to.equal(daiUsdAggregator.address);
    expect(await valuator.getAggregatorByToken(weth.address)).to.equal(ethUsdAggregator.address);
    expect(await valuator.getAggregatorByToken(usdc.address)).to.equal(usdcEthAggregator.address);
    expect(await valuator.getAggregatorByToken(usdt.address)).to.equal(usdtEthAggregator.address);
  });

  it('should get token value for each deployed token', async () => {
    const value1 = new BN("3000000000000000000");
    const expectedValue1 = new BN("3018000000000000000");
    (await valuator.getTokenValue(dai.address, value1)).should.be.bignumber.equal(expectedValue1);

    const value2 = new BN("1000000000");
    const expectedValue2 = new BN("630486364");
    (await valuator.getTokenValue(usdc.address, value2)).should.be.bignumber.equal(expectedValue2);

    const value3 = new BN("4000000000000000000");
    const expectedValue3 = new BN("539480000000000000000");
    (await valuator.getTokenValue(weth.address, value3)).should.be.bignumber.equal(expectedValue3);

    const usdtEthPrice = new BN("4674780000000000");
    const ethUsdPrice = new BN("13487000000");
    const ethFactor = new BN(10).pow(new BN(18));
    const usdFactor = new BN(1e8);
    const value4 = new BN("1000000000");
    const expectedValue4 = value4.mul(usdtEthPrice).div(ethFactor).mul(ethUsdPrice).div(usdFactor);
    (await valuator.getTokenValue(usdt.address, value4)).should.be.bignumber.equal(expectedValue4);
  });

  it('should change aggregator when called by owner', async () => {
    const result = await valuator.insertOrUpdateOracleToken(
      newTokenAddress,
      newAggregatorAddress,
      newQuoteSymbol,
      {from: owner},
    );
    expectEvent(
      result,
      'TokenInsertedOrUpdated',
      {token: newTokenAddress, aggregator: newAggregatorAddress, quoteSymbol: newQuoteSymbol},
    );
    expect(await valuator.getAggregatorByToken(newTokenAddress)).equal(newAggregatorAddress);
    expect(await valuator.getQuoteSymbolByToken(newTokenAddress)).equal(newQuoteSymbol);
  });

  it('should change aggregator when called by guardian', async () => {
    const result = await valuator.insertOrUpdateOracleToken(
      newTokenAddress,
      newAggregatorAddress,
      newQuoteSymbol,
      {from: guardian},
    );
    expectEvent(
      result,
      'TokenInsertedOrUpdated',
      {token: newTokenAddress, aggregator: newAggregatorAddress, quoteSymbol: newQuoteSymbol},
    );
    expect(await valuator.getAggregatorByToken(newTokenAddress)).equal(newAggregatorAddress);
    expect(await valuator.getQuoteSymbolByToken(newTokenAddress)).equal(newQuoteSymbol);
  });

  it('should not change aggregator when not called by owner or guardian', async () => {
    await expectRevert(
      valuator.insertOrUpdateOracleToken(newTokenAddress, newAggregatorAddress, newQuoteSymbol, {from: other}),
      'OwnableOrGuardian: UNAUTHORIZED_OWNER_OR_GUARDIAN'
    );
  });

  it('should revert when given an invalid address', async () => {
    const invalidAddress = constants.ZERO_ADDRESS;
    await expectRevert(
      valuator.getTokenValue(invalidAddress, new BN("1000000000000000000")),
      'UnderlyingTokenValuatorImplV5::getTokenValue: INVALID_TOKEN'
    );
  });
});
