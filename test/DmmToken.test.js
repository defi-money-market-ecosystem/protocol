const { setupLoader } = require('@openzeppelin/contract-loader');

const {accounts, contract} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectRevert} = require('@openzeppelin/test-helpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, deployer, user] = accounts;

const loader = setupLoader({
  provider: contract.provider,
  defaultGas: 7000000,
  defaultSender: user,
});

// Create a contract object from a compilation artifact
const DmmBlacklistable = loader.truffle.fromArtifact('DmmBlacklistable');
const DmmControllerMock = loader.truffle.fromArtifact('DmmControllerMock');
const DmmToken = loader.truffle.fromArtifact('DmmToken');
const ERC20Mock = loader.truffle.fromArtifact('ERC20Mock');
const SafeERC20 = loader.truffle.fromArtifact('SafeERC20');
const SafeMath = loader.truffle.fromArtifact('SafeMath');

describe('DmmToken', () => {

  beforeEach(async () => {
    await ERC20Mock.detectNetwork();
    await DmmToken.detectNetwork();

    const safeERC20 = await SafeERC20.new();
    const safeMath = await SafeMath.new();

    ERC20Mock.link("SafeMath", safeMath.address);

    DmmToken.link("SafeERC20", safeERC20.address);
    DmmToken.link("SafeMath", safeMath.address);

    this.blacklistable = await DmmBlacklistable.new();
    this.underlyingToken = await ERC20Mock.new();
    this.controller = await DmmControllerMock.new(this.blacklistable.address, this.underlyingToken.address);

    const symbol = "DAI";
    const name = "Dai Stablecoin";
    const decimals = 18;
    const minMintAmount = new BN("1000000000000000000"); //  1.0
    const minRedeemAmount = new BN("1000000000000000000"); // 1.0
    const totalSupply = new BN("10000000000000000000000"); // 10,000

    this.contract = await DmmToken.new(
      symbol,
      name,
      decimals,
      minMintAmount,
      minRedeemAmount,
      totalSupply,
      this.controller.address,
      {from: admin, gas: contract.defaultGas, defaultGas: contract.defaultGas}
    );
  });

  it('should get the pausable contract', async () => {
    const pausable = await this.contract.pausable();
    expect(pausable).to.equal(this.controller.address);
  });
});
