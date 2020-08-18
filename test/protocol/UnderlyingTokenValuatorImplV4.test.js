const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectEvent, expectRevert} = require('@openzeppelin/test-helpers');


// Use the different accounts, which are unlocked and funded with Ether
const [owner] = accounts;

// Create a contract object from a compilation artifact
const ERC20Mock = contract.fromArtifact('ERC20Mock');
const WETHMock = contract.fromArtifact('WETHMock');
const DaiUsdAggregatorMock = contract.fromArtifact('DaiUsdAggregatorMock');
const EthUsdAggregatorMock = contract.fromArtifact('EthUsdAggregatorMockV2');
const UsdcEthAggregatorMock = contract.fromArtifact('UsdcEthAggregatorMock');
const UsdtEthAggregatorMock = contract.fromArtifact('UsdtEthAggregatorMock');
const SafeMath = contract.fromArtifact('SafeMath');
const StringHelpers = contract.fromArtifact('StringHelpers');
const UnderlyingTokenValuatorImplV4 = contract.fromArtifact('UnderlyingTokenValuatorImplV4');

describe('UnderlyingTokenValuatorImplV4', () => {
  let valuator = null;
  let dai = null;
  let usdc = null;
  let usdt = null;
  let weth = null;
  let daiUsdAggregator = null;
  let ethUsdAggregator = null;
  let usdcEthAggregator = null;
  let usdtEthAggregator = null;

  beforeEach(async () => {
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

    await UnderlyingTokenValuatorImplV4.detectNetwork();
    UnderlyingTokenValuatorImplV4.link("StringHelpers", stringHelpers.address);

    valuator = await UnderlyingTokenValuatorImplV4.new(
      dai.address,
      usdc.address,
      usdt.address,
      weth.address,
      daiUsdAggregator.address,
      ethUsdAggregator.address,
      usdcEthAggregator.address,
      usdtEthAggregator.address,
      {from: owner}
    );
  });

  it('should get token properties', async () => {
    // Store a value - recall that only the owner account can do this!
    expect(await valuator.dai()).to.equal(dai.address);
    expect(await valuator.usdc()).to.equal(usdc.address);
    expect(await valuator.usdt()).to.equal(usdt.address);
    expect(await valuator.weth()).to.equal(weth.address);

    expect(await valuator.daiUsdAggregator()).to.equal(daiUsdAggregator.address);
    expect(await valuator.ethUsdAggregator()).to.equal(ethUsdAggregator.address);
    expect(await valuator.usdcEthAggregator()).to.equal(usdcEthAggregator.address);
    expect(await valuator.usdtEthAggregator()).to.equal(usdtEthAggregator.address);
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

  it('should change USDT-WETH aggregator when called by owner', async () => {
    const result = await valuator.setUsdtEthAggregator(constants.ZERO_ADDRESS, {from: owner});
    expectEvent(
      result,
      'UsdtEthAggregatorChanged',
      {oldAggregator: usdtEthAggregator.address, newAggregator: constants.ZERO_ADDRESS}
    );
    expect(await valuator.usdtEthAggregator()).equal(constants.ZERO_ADDRESS);
  });

  it('should not change USDT-WETH aggregator when not called by owner', async () => {
    await expectRevert.unspecified(
      valuator.setUsdtEthAggregator(constants.ZERO_ADDRESS),
    );
  });

  it('should revert when given an invalid address', async () => {
    const invalidAddress = constants.ZERO_ADDRESS;
    await expectRevert.unspecified(
      valuator.getTokenValue(invalidAddress, new BN("1000000000000000000")),
    );
  });
});
