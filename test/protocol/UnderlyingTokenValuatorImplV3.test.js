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
const SafeMath = contract.fromArtifact('SafeMath');
const StringHelpers = contract.fromArtifact('StringHelpers');
const UnderlyingTokenValuatorImplV3 = contract.fromArtifact('UnderlyingTokenValuatorImplV3');

describe('UnderlyingTokenValuatorImplV3', () => {
  let valuator = null;
  let dai = null;
  let usdc = null;
  let weth = null;
  let daiUsdAggregator = null;
  let ethUsdAggregator = null;
  let usdcEthAggregator = null;

  beforeEach(async () => {
    await ERC20Mock.detectNetwork();
    const safeMath = await SafeMath.new();

    ERC20Mock.link("SafeMath", safeMath.address);

    dai = await ERC20Mock.new();
    usdc = await ERC20Mock.new();
    weth = await WETHMock.new();

    const stringHelpers = await StringHelpers.new();

    daiUsdAggregator = await DaiUsdAggregatorMock.new();
    ethUsdAggregator = await EthUsdAggregatorMock.new();
    usdcEthAggregator = await UsdcEthAggregatorMock.new();

    await UnderlyingTokenValuatorImplV3.detectNetwork();
    UnderlyingTokenValuatorImplV3.link("StringHelpers", stringHelpers.address);

    valuator = await UnderlyingTokenValuatorImplV3.new(
      dai.address,
      usdc.address,
      weth.address,
      daiUsdAggregator.address,
      ethUsdAggregator.address,
      usdcEthAggregator.address,
      {from: owner}
    );
  });

  it('should get token properties', async () => {
    // Store a value - recall that only the owner account can do this!
    expect(await valuator.dai()).to.equal(dai.address);
    expect(await valuator.usdc()).to.equal(usdc.address);
    expect(await valuator.weth()).to.equal(weth.address);

    expect(await valuator.daiUsdAggregator()).to.equal(daiUsdAggregator.address);
    expect(await valuator.ethUsdAggregator()).to.equal(ethUsdAggregator.address);
    expect(await valuator.usdcEthAggregator()).to.equal(usdcEthAggregator.address);
  });

  it('should get token value for each deployed token', async () => {
    const value1 = new BN("3000000000000000000");
    const expectedValue1 = new BN("3018000000000000000");
    (await valuator.getTokenValue(dai.address, value1)).should.be.bignumber.equal(expectedValue1);

    const value2 = new BN("1000000000");
    const expectedValue2 = new BN("630486364");
    (await valuator.getTokenValue(usdc.address, value2)).should.be.bignumber.equal(expectedValue2);

    const value3 = new BN("4000000000000000000");
    const expectedUsdValue = new BN("539480000000000000000");
    (await valuator.getTokenValue(weth.address, value3)).should.be.bignumber.equal(expectedUsdValue);
  });

  it('should change DAI-USD aggregator when called by owner', async () => {
    const result = await valuator.setDaiUsdAggregator(constants.ZERO_ADDRESS, {from: owner});
    expectEvent(
      result,
      'DaiUsdAggregatorChanged',
      {oldAggregator: daiUsdAggregator.address, newAggregator: constants.ZERO_ADDRESS}
    );
    expect(await valuator.daiUsdAggregator()).equal(constants.ZERO_ADDRESS);
  });

  it('should not change DAI-USD aggregator when not called by owner', async () => {
    await expectRevert.unspecified(
      valuator.setDaiUsdAggregator(constants.ZERO_ADDRESS),
    )
  });

  it('should change ETH-USD aggregator when called by owner', async () => {
    const result = await valuator.setEthUsdAggregator(constants.ZERO_ADDRESS, {from: owner});
    expectEvent(
      result,
      'EthUsdAggregatorChanged',
      {oldAggregator: ethUsdAggregator.address, newAggregator: constants.ZERO_ADDRESS}
    );
    expect(await valuator.ethUsdAggregator()).equal(constants.ZERO_ADDRESS);
  });

  it('should not change ETH-USD aggregator when not called by owner', async () => {
    await expectRevert.unspecified(
      valuator.setEthUsdAggregator(constants.ZERO_ADDRESS),
    )
  });

  it('should change USDC-ETH aggregator when called by owner', async () => {
    const result = await valuator.setUsdcEthAggregator(constants.ZERO_ADDRESS, {from: owner});
    expectEvent(
      result,
      'UsdcEthAggregatorChanged',
      {oldAggregator: usdcEthAggregator.address, newAggregator: constants.ZERO_ADDRESS}
    );
    expect(await valuator.usdcEthAggregator()).equal(constants.ZERO_ADDRESS);
  });

  it('should not change USDC-ETH aggregator when not called by owner', async () => {
    await expectRevert.unspecified(
      valuator.setUsdcEthAggregator(constants.ZERO_ADDRESS),
    )
  });

  it('should revert when given an invalid address', async () => {
    const invalidAddress = constants.ZERO_ADDRESS;
    await expectRevert.unspecified(
      valuator.getTokenValue(invalidAddress, new BN("1000000000000000000")),
    )
  });
});
