const {accounts, contract} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/configure');
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectRevert} = require('@openzeppelin/test-helpers');


// Use the different accounts, which are unlocked and funded with Ether
const [admin, deployer, user] = accounts;

// Create a contract object from a compilation artifact
const ERC20Mock = contract.fromArtifact('ERC20Mock');
const SafeMath = contract.fromArtifact('SafeMath');
const StringHelpers = contract.fromArtifact('StringHelpers');
const UnderlyingTokenValuatorImplV1 = contract.fromArtifact('UnderlyingTokenValuatorImplV1');

describe('UnderlyingTokenValuatorImplV1', () => {
  const [owner] = accounts;
  let valuator = null;
  let dai = null;
  let usdc = null;

  beforeEach(async () => {
    await ERC20Mock.detectNetwork();
    const safeMath = await SafeMath.new();

    ERC20Mock.link("SafeMath", safeMath.address);

    dai = await ERC20Mock.new();
    usdc = await ERC20Mock.new();

    const stringHelpers = await StringHelpers.new();

    await UnderlyingTokenValuatorImplV1.detectNetwork();
    UnderlyingTokenValuatorImplV1.link("StringHelpers", stringHelpers.address);

    valuator = await UnderlyingTokenValuatorImplV1.new(dai.address, usdc.address);
  });

  it('should get token properties', async () => {
    // Store a value - recall that only the owner account can do this!
    expect(await valuator.usdc()).to.equal(usdc.address);
    expect(await valuator.dai()).to.equal(dai.address);
  });

  it('should get token value for each deployed token', async () => {
    // Store a value - recall that only the owner account can do this!
    const value1 = new BN("1000000000000000000");
    (await valuator.getTokenValue(usdc.address, value1)).should.be.bignumber.equal(value1);

    const value2 = new BN("3000000000000000000");
    (await valuator.getTokenValue(dai.address, value2)).should.be.bignumber.equal(value2);
  });

  it('should revert when given an invalid address', async () => {
    const invalidAddress = constants.ZERO_ADDRESS;
    await expectRevert.unspecified(
      valuator.getTokenValue(invalidAddress, new BN("1000000000000000000")),
    )
  })
});
