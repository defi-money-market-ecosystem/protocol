const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {expectRevert, expectEvent, BN} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1} = require('../../helpers/DmmTokenTestHelpers');
const {doAssetIntroducerV1BeforeEach} = require('../../helpers/AssetIntroductionHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, owner] = accounts;

describe('AssetIntroducerV1.Misc', () => {
  let snapshotId;
  before(async () => {
    this.admin = admin;
    this.guardian = guardian;
    this.owner = owner;
    this.user = user;

    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);

    await doAssetIntroducerV1BeforeEach(this, contract, web3);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('baseURI: should get baseURI', async () => {
    const baseURI = await this.assetIntroducer.baseURI();
    (baseURI).should.eq(this.baseURI);
  });

  it('openSeaProxy: should get openSeaProxy', async () => {
    (await this.assetIntroducer.openSeaProxyRegistry()).should.eq(this.openSeaProxyRegistry.address);
  });

  it('owner: should get owner', async () => {
    (await this.assetIntroducer.owner()).should.be.eq(owner);
  });

  it('guardian: should get guardian', async () => {
    (await this.assetIntroducer.guardian()).should.be.eq(guardian);
  });

  it('guardian: should get guardian', async () => {
    (await this.assetIntroducer.guardian()).should.be.eq(guardian);
  });

  it('dmg: should get dmg', async () => {
    (await this.assetIntroducer.dmg()).should.be.eq(this.dmgToken.address);
  });

  it('dmmController: should get dmmController', async () => {
    (await this.assetIntroducer.dmmController()).should.be.eq(this.dmmController.address);
  });

  it('underlyingTokenValuator: should get underlyingTokenValuator', async () => {
    (await this.assetIntroducer.underlyingTokenValuator()).should.be.eq(this.underlyingTokenValuator.address);
  });

  it('initTimestamp: should get initial timestamp', async () => {
    const blockNumber = (await web3.eth.getTransactionReceipt(this.proxy.transactionHash)).blockNumber
    const blockTimestamp = new BN((await web3.eth.getBlock(blockNumber)).timestamp.toString())
    const initTimestamp = await this.assetIntroducer.initTimestamp();
    (initTimestamp).should.be.bignumber.eq(blockTimestamp);
  });

  it('domainSeparator: should get domainSeparator', async () => {
    // abi.encode(DOMAIN_TYPE_HASH, keccak256(bytes(NAME)), EvmUtil.getChainId(), address(this))
    const domainTypeHash = await this.assetIntroducer.DOMAIN_TYPE_HASH();
    const hashedName = web3.utils.sha3(await this.assetIntroducer.name());
    const encodedDomainSeparator = web3.eth.abi.encodeParameters(
      ['bytes32', 'bytes32', 'uint', 'address'],
      [domainTypeHash, hashedName, '1', this.proxy.address],
    );
    const expectedDomainSeparator = web3.utils.sha3(encodedDomainSeparator);
    const domainSeparator = await this.assetIntroducer.domainSeparator();
    (domainSeparator).should.be.eq(expectedDomainSeparator);
  });

  it('DOMAIN_TYPE_HASH: should get DOMAIN_TYPE_HASH', async () => {
    const expectedTypeHash = web3.utils.sha3("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    const typeHash = await this.assetIntroducer.DOMAIN_TYPE_HASH();
    (typeHash).should.equal(expectedTypeHash);
  });

  it('assetIntroducerDiscount: should get assetIntroducerDiscount', async () => {
    const assetIntroducerDiscount = await this.assetIntroducer.assetIntroducerDiscount();
    (assetIntroducerDiscount).should.equal(this.assetIntroducerDiscount.address);
  });

});