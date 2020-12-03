let {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {expectRevert, expectEvent, BN} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1} = require('../../helpers/DmmTokenTestHelpers');
const {doDmgIncentivePoolBeforeEach} = require('../../helpers/AssetIntroductionHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, owner] = accounts;

describe('DMGIncentivePool', () => {
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

    await doDmgIncentivePoolBeforeEach(this, contract, web3);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('withdrawTo: should work for owner', async () => {
    const amount = new BN('100000000000000000000');
    await this.incentivePool.withdrawTo(this.dmgToken.address, owner, amount, {from: owner});
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(amount);
  });

  it('withdrawTo: should not work for non-owner', async () => {
    const amount = new BN('100000000000000000000');
    await expectRevert.unspecified(this.incentivePool.withdrawTo(this.dmgToken.address, owner, amount, {from: user}))
  });

  it('withdrawAllTo: should work for owner', async () => {
    const amount = new BN('500000000000000000000');
    await this.incentivePool.withdrawAllTo(this.dmgToken.address, owner, {from: owner});
    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(amount);
  });

  it('withdrawAllTo: should not work for non-owner', async () => {
    await expectRevert.unspecified(this.incentivePool.withdrawAllTo(owner, this.dmgToken.address, {from: user}))
  });

  it('enableSpender: should work for owner', async () => {
    const amount = new BN('500000000000000000000');
    await this.incentivePool.enableSpender(this.dmgToken.address, user, {from: owner});
    await this.dmgToken.transferFrom(this.incentivePool.address, owner, amount, {from: user});

    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(amount);
  });

  it('enableSpender: should not work for non-owner', async () => {
    await expectRevert.unspecified(this.incentivePool.enableSpender(owner, this.dmgToken.address, {from: user}))
  });

  it('disableSpender: should work for owner', async () => {
    const amount = new BN('500000000000000000000');
    await this.incentivePool.enableSpender(this.dmgToken.address, user, {from: owner});
    await this.incentivePool.disableSpender(this.dmgToken.address, user, {from: owner});
    await expectRevert.unspecified(this.dmgToken.transferFrom(this.incentivePool.address, owner, amount, {from: user}));

    (await this.dmgToken.balanceOf(owner)).should.be.bignumber.eq(new BN('0'));
  });

  it('disableSpender: should not work for non-owner', async () => {
    await expectRevert.unspecified(this.incentivePool.disableSpender(owner, this.dmgToken.address, {from: user}))
  });

});