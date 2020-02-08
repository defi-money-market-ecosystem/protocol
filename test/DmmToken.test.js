const {accounts, contract, web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectRevert} = require('@openzeppelin/test-helpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, deployer, user] = accounts;

// Create a contract object from a compilation artifact
const DmmBlacklistable = contract.fromArtifact('DmmBlacklistable');
const DmmControllerMock = contract.fromArtifact('DmmControllerMock');
const DmmToken = contract.fromArtifact('DmmToken');
const DmmTokenLibrary = contract.fromArtifact('DmmTokenLibrary');
const ERC20Mock = contract.fromArtifact('ERC20Mock');
const SafeERC20 = contract.fromArtifact('SafeERC20');
const SafeMath = contract.fromArtifact('SafeMath');

describe('DmmToken', () => {

  beforeEach(async () => {
    await ERC20Mock.detectNetwork();
    await DmmToken.detectNetwork();
    await DmmTokenLibrary.detectNetwork();

    const safeERC20 = await SafeERC20.new();
    const safeMath = await SafeMath.new();
    const dmmTokenLibrary = await DmmTokenLibrary.new();

    ERC20Mock.link("SafeMath", safeMath.address);

    DmmToken.link("SafeERC20", safeERC20.address);
    DmmToken.link("SafeMath", safeMath.address);
    DmmToken.link("DmmTokenLibrary", dmmTokenLibrary.address);

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
      {from: admin}
    );

    const tx = await web3.eth.getTransaction(this.contract.transactionHash);
    console.log("TX: ", tx);

    const receipt = await web3.eth.getTransactionReceipt(this.contract.transactionHash);
    console.log("RECEIPT: ", receipt);
  });

  it('should get the pausable contract', async () => {
    const pausable = await this.contract.pausable();
    expect(pausable).to.equal(this.controller.address);
  });
});
