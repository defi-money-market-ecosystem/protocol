const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectEvent, expectRevert} = require('@openzeppelin/test-helpers');
const {snapshotChain, resetChain, _1} = require('../helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [owner, guardian, admin, other] = accounts;

// Create a contract object from a compilation artifact
const ERC20Mock = contract.fromArtifact('ERC20Mock');
const WETHMock = contract.fromArtifact('WETHMock');
const SafeMath = contract.fromArtifact('SafeMath');
const StringHelpers = contract.fromArtifact('StringHelpers');
const OffChainAssetValuatorProxy = contract.fromArtifact('OffChainAssetValuatorProxy');
const OffChainAssetValuatorImplV2 = contract.fromArtifact('OffChainAssetValuatorImplV2');

describe('OffChainAssetValuatorImplV2', () => {
  let snapshotId;

  const newTokenAddress = web3.utils.toChecksumAddress('0x1000000000000000000000000000000000000000');
  const newAggregatorAddress = web3.utils.toChecksumAddress('0x0000000000000000000000000000000000000001');
  const newQuoteSymbol = web3.utils.toChecksumAddress('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF');

  let valuator;

  before(async () => {
    await ERC20Mock.detectNetwork();
    const safeMath = await SafeMath.new();

    ERC20Mock.link("SafeMath", safeMath.address);

    this.link = await ERC20Mock.new();

    const stringHelpers = await StringHelpers.new();

    await OffChainAssetValuatorImplV2.detectNetwork();
    OffChainAssetValuatorImplV2.link("StringHelpers", stringHelpers.address);

    this.implementation = await OffChainAssetValuatorImplV2.new();

    console.log('this.implementation ', (await web3.eth.getTransactionReceipt(this.implementation.transactionHash)).gasUsed.toString());

    this.proxy = await OffChainAssetValuatorProxy.new(
      this.implementation.address,
      admin,
      owner,
      guardian,
      this.link.address,
      _1(),
      _1(),
      '0x0000000000000000000000000000000000000000000000000000000000000001',
      {from: owner},
    );

    valuator = contract.fromArtifact('OffChainAssetValuatorImplV2', this.proxy.address);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('addSupportedAssetTypeByTokenId: should work when sent by owner', async () => {
    const tokenId = new BN('1');
    const assetType = 'PLANE';
    const result = await valuator.addSupportedAssetTypeByTokenId(tokenId, assetType, {from: owner});
    expectEvent(
      result,
      'AssetTypeSet',
      {tokenId, assetType, isAdded: true}
    );
  });

  it('addSupportedAssetTypeByTokenId: should work when sent by guardian', async () => {
    const tokenId = new BN('1');
    const assetType = 'PLANE';
    const result = await valuator.addSupportedAssetTypeByTokenId(tokenId, assetType, {from: guardian});
    expectEvent(
      result,
      'AssetTypeSet',
      {tokenId, assetType, isAdded: true}
    );
  });

  it('addSupportedAssetTypeByTokenId: should fail when sent by other', async () => {
    const tokenId = new BN('1');
    const assetType = 'PLANE';
    await expectRevert(
      valuator.addSupportedAssetTypeByTokenId(tokenId, assetType, {from: other}),
      'OwnableOrGuardian: UNAUTHORIZED_OWNER_OR_GUARDIAN'
    );
  });

  it('removeSupportedAssetTypeByTokenId: should work when sent by owner', async () => {
    const tokenId = new BN('1');
    const assetType = 'PLANE';
    let result = await valuator.addSupportedAssetTypeByTokenId(tokenId, assetType, {from: owner});
    expectEvent(
      result,
      'AssetTypeSet',
      {tokenId, assetType, isAdded: true}
    );

    result = await valuator.removeSupportedAssetTypeByTokenId(tokenId, assetType, {from: owner});
    expectEvent(
      result,
      'AssetTypeSet',
      {tokenId, assetType, isAdded: false}
    );
  });

  it('removeSupportedAssetTypeByTokenId: should work when sent by guardian', async () => {
    const tokenId = new BN('1');
    const assetType = 'PLANE';
    let result = await valuator.addSupportedAssetTypeByTokenId(tokenId, assetType, {from: guardian});
    expectEvent(
      result,
      'AssetTypeSet',
      {tokenId, assetType, isAdded: true}
    );

    result = await valuator.removeSupportedAssetTypeByTokenId(tokenId, assetType, {from: guardian});
    expectEvent(
      result,
      'AssetTypeSet',
      {tokenId, assetType, isAdded: false}
    );
  });

  it('removeSupportedAssetTypeByTokenId: should fail when sent by other', async () => {
    const tokenId = new BN('1');
    const assetType = 'PLANE';
    let result = await valuator.addSupportedAssetTypeByTokenId(tokenId, assetType, {from: guardian});
    expectEvent(
      result,
      'AssetTypeSet',
      {tokenId, assetType, isAdded: true}
    );

    await expectRevert(
      valuator.removeSupportedAssetTypeByTokenId(tokenId, assetType, {from: other}),
      'OwnableOrGuardian: UNAUTHORIZED_OWNER_OR_GUARDIAN'
    );
  });
});
