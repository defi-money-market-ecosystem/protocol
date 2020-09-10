const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {BN, constants, expectRevert, expectEvent, time, balance} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1, _10, _100, _10000} = require('../../helpers/DmmTokenTestHelpers');
const {doBurningBeforeEach} = require('../../helpers/BurningHelpers')

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, owner, user, spender, receiver] = accounts;

describe('DMGBurnerV1', () => {
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

    await doBurningBeforeEach(this, contract, web3, provider);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    snapshotId = await resetChain(provider, snapshotId);
  });

  it('burnDmg should burn using WETH', async () => {
    const result = await this.burner.burnDmg(
      this.tokenA.address,
      _1(),
      [this.tokenA.address, this.dmgToken.address],
      {from: admin},
    );
    expectEvent(result, 'DmgBurned', {burner: admin});
  });

  it('burnDmg should burn using any token', async () => {
    const result = await this.burner.burnDmg(
      this.tokenB.address,
      _1(),
      [this.tokenB.address, this.tokenA.address, this.dmgToken.address],
      {from: admin},
    );
    expectEvent(result, 'DmgBurned', {burner: admin});
  });

  it('burnDmg should fail when path is not correct', async () => {
    await expectRevert(
      this.burner.burnDmg(
        this.tokenB.address,
        _1(),
        [this.dmgToken.address, this.tokenA.address, this.tokenB.address],
      ),
      'DMGBurnerV1::burnDmg: INVALID_HEAD_TOKEN'
    );
  });

});