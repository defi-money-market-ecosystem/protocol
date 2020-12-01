const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {expectRevert, expectEvent, BN} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1} = require('../../helpers/DmmTokenTestHelpers');
const {doAssetIntroductionV1BeforeEach} = require('../../helpers/AssetIntroductionHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, owner] = accounts;

describe('AssetIntroducerV1.Admin', () => {
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

    await doAssetIntroductionV1BeforeEach(this, contract, web3);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('baseURI: should get baseURI', async () => {
    const baseURI = await this.assetIntroducer.baseURI();
    (baseURI).should.eq(this.baseURI);
  });

  it('initTimestamp: should get initial timestamp', async () => {
    const blockNumber = (await web3.eth.getTransactionReceipt(this.proxy.transactionHash)).blockNumber
    const blockTimestamp = new BN((await web3.eth.getBlock(blockNumber)).timestamp.toString())
    const initTimestamp = await this.assetIntroducer.initTimestamp();
    (initTimestamp).should.be.bignumber.eq(blockTimestamp);
  });

});