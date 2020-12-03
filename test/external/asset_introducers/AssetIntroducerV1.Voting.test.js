const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {expectRevert, expectEvent, BN, time} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1} = require('../../helpers/DmmTokenTestHelpers');
const {doAssetIntroducerV1BeforeEach, createNFTs} = require('../../helpers/AssetIntroductionHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, user2, owner, other] = accounts;

describe('AssetIntroducerV1.Voting', () => {
  let snapshotId;
  before(async () => {
    this.admin = admin;
    this.guardian = guardian;
    this.owner = owner;
    this.user = user;
    this.user2 = user2;

    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);

    await doAssetIntroducerV1BeforeEach(this, contract, web3);
    await createNFTs(this);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('getCurrentVotes: should work for user #1', async () => {
    let totalDmgLocked = new BN('0');
    for(let i = 0; i < this.purchaseResults[user].length; i++) {
      const eventLogs = this.purchaseResults[user][i].logs;
      const purchaseLog = eventLogs[eventLogs.length - 1];
      totalDmgLocked = totalDmgLocked.add(purchaseLog.args.dmgAmount);
    }
    (await this.assetIntroducer.getCurrentVotes(user)).should.be.bignumber.eq(totalDmgLocked);
  });

  it('getCurrentVotes: should work for user #2', async () => {
    let totalDmgLocked = new BN('0');
    for(let i = 0; i < this.purchaseResults[user2].length; i++) {
      const eventLogs = this.purchaseResults[user2][i].logs;
      const purchaseLog = eventLogs[eventLogs.length - 1];
      totalDmgLocked = totalDmgLocked.add(purchaseLog.args.dmgAmount);
    }
    (await this.assetIntroducer.getCurrentVotes(user2)).should.be.bignumber.eq(totalDmgLocked);
  });

  it('getCurrentVotes: should work for other', async () => {
    (await this.assetIntroducer.getCurrentVotes(other)).should.be.bignumber.eq(new BN('0'));

    const dmgTransferAmount = this.purchaseResults[user][0].logs[4].args.dmgAmount;
    (await this.assetIntroducer.transferFrom(user, other, this.tokenIds[0], {from: user}));
    (await this.assetIntroducer.getCurrentVotes(other)).should.be.bignumber.eq(dmgTransferAmount);
  });

  it('getPriorVotes: should work for user #1', async () => {
    (await time.advanceBlock());

    (await this.assetIntroducer.getPriorVotes(user, 0)).should.be.bignumber.eq(new BN('0'));

    const purchase0Event = this.purchaseResults[user][0].logs[4];
    (await this.assetIntroducer.getPriorVotes(user, purchase0Event.blockNumber)).should.be.bignumber.eq(purchase0Event.args.dmgAmount);

    const purchase1Event = this.purchaseResults[user][1].logs[4];
    (await this.assetIntroducer.getPriorVotes(user, purchase1Event.blockNumber)).should.be.bignumber.eq(purchase0Event.args.dmgAmount.add(purchase1Event.args.dmgAmount));
  });

  it('getPriorVotes: should work for user #2', async () => {
    (await time.advanceBlock());

    (await this.assetIntroducer.getPriorVotes(user2, 0)).should.be.bignumber.eq(new BN('0'));

    const purchase0Event = this.purchaseResults[user2][0].logs[4];
    (await this.assetIntroducer.getPriorVotes(user2, purchase0Event.blockNumber)).should.be.bignumber.eq(purchase0Event.args.dmgAmount);

    const purchase1Event = this.purchaseResults[user2][1].logs[4];
    (await this.assetIntroducer.getPriorVotes(user2, purchase1Event.blockNumber)).should.be.bignumber.eq(purchase0Event.args.dmgAmount.add(purchase1Event.args.dmgAmount));
  });

  it('getPriorVotes: should work for other', async () => {
    (await time.advanceBlock());

    (await this.assetIntroducer.getPriorVotes(other, 0)).should.be.bignumber.eq(new BN('0'));
    (await this.assetIntroducer.getPriorVotes(other, (await time.latestBlock()).sub(new BN('1')))).should.be.bignumber.eq(new BN('0'));
  });

  it('getPriorVotes: should work for user #1 after transferring token to user #2', async () => {
    const previousCountUser1 = (await this.assetIntroducer.getCurrentVotes(user));
    const previousCountUser2 = (await this.assetIntroducer.getCurrentVotes(user2));

    (await this.assetIntroducer.transferFrom(user, user2, this.tokenIds[0], {from: user}));

    const transferAmount = this.purchaseResults[user][0].logs[4].args.dmgAmount;
    (await this.assetIntroducer.getCurrentVotes(user)).should.be.bignumber.eq(previousCountUser1.sub(transferAmount));
    (await this.assetIntroducer.getCurrentVotes(user2)).should.be.bignumber.eq(previousCountUser2.add(transferAmount));

    (await this.assetIntroducer.getPriorVotes(user, 0)).should.be.bignumber.eq(new BN('0'));

    const purchase0Event = this.purchaseResults[user][0].logs[4];
    (await this.assetIntroducer.getPriorVotes(user, purchase0Event.blockNumber)).should.be.bignumber.eq(purchase0Event.args.dmgAmount);

    const purchase1Event = this.purchaseResults[user][1].logs[4];
    (await this.assetIntroducer.getPriorVotes(user, purchase1Event.blockNumber)).should.be.bignumber.eq(purchase0Event.args.dmgAmount.add(purchase1Event.args.dmgAmount));
  });

});