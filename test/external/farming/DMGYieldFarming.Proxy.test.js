const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {expectRevert, expectEvent} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1} = require('../../helpers/DmmTokenTestHelpers');
const {doYieldFarmingV1BeforeEach} = require('../../helpers/YieldFarmingHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, owner] = accounts;

describe('DMGYieldFarming.Proxy', () => {
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

    await doYieldFarmingV1BeforeEach(this, contract, web3);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('admin: should get admin on proxy contract', async () => {
    const result = await this.proxy.admin({from: admin});
    (result.receipt.status).should.eq(true)
  });

  it('upgradeTo: should upgrade proxy to new address', async () => {
    const result = await this.proxy.upgradeTo(this.dmmController.address, {from: admin});
    (result.receipt.status).should.eq(true);
    expectEvent(result.receipt, 'Upgraded', {'implementation': this.dmmController.address});

    (await this.proxy.getImplementation()).should.eq(this.dmmController.address);
  });

  it('guardian: should call function on implementation contract', async () => {
    (await this.yieldFarming.guardian()).should.eq(guardian);
  });

  it('guardian: should call function on implementation contract when using admin', async () => {
    (await this.yieldFarming.guardian({from: admin})).should.eq(guardian);
  });

  it('initialize: should not call initialize again', async () => {
    const methodName = 'initialize(address,address,address,uint256,address[],address[],uint8[],uint16[])';
    const promise = this.yieldFarming.methods[methodName](
      this.dmgToken.address,
      guardian,
      this.dmmController.address,
      _1(),
      [this.tokenA.address],
      [this.underlyingTokenA.address],
      ['8'],
      ['100'],
      {from: admin},
    );
    await expectRevert(promise, 'Contract instance has already been initialized')
  });

});