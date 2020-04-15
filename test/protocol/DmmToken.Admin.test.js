const {accounts, contract, web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const {
  _0,
  _100,
  _10000,
  doDmmTokenBeforeEach,
  setApproval,
  setBalanceFor,
  mint,
  pauseEcosystem,
} = require('../helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, user] = accounts;

describe('DmmToken.Admin', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doDmmTokenBeforeEach(this, contract, web3);
  });

  /********************************
   * Increase the Total Supply
   */

  it('should increase total supply if sent by admin', async () => {
    const receipt = await this.contract.increaseTotalSupply(_100(), {from: admin});
    expectEvent(receipt, 'TotalSupplyIncreased', {oldTotalSupply: _10000(), newTotalSupply: _10000().add(_100())});
    (await this.contract.balanceOf(this.contract.address)).should.be.bignumber.equal(_10000().add(_100()));
  });

  it('should fail to increase total supply if not sent by admin', async () => {
    await expectRevert(
      this.contract.increaseTotalSupply(_100(), {from: user}),
      'Ownable: caller is not the owner'
    )
  });

  it('should fail to increase total supply if ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);

    await expectRevert(
      this.contract.increaseTotalSupply(_100(), {from: admin}),
      'ECOSYSTEM_PAUSED'
    )
  });

  /********************************
   * Decrease the Total Supply
   */

  it('should decrease total supply if sent by admin', async () => {
    const receipt = await this.contract.decreaseTotalSupply(_100(), {from: admin});
    expectEvent(
      receipt,
      'TotalSupplyDecreased',
      {oldTotalSupply: _10000(), newTotalSupply: _10000().sub(_100())}
    );
    (await this.contract.balanceOf(this.contract.address)).should.be.bignumber.equal(_10000().sub(_100()));
  });

  it('should fail to decrease total supply if there is too much active supply', async () => {
    await mint(this.underlyingToken, this.contract, user, _10000());
    await expectRevert(
      this.contract.decreaseTotalSupply(_100(), {from: admin}),
      'TOO_MUCH_ACTIVE_SUPPLY'
    )
  });

  it('should fail to decrease total supply if not sent by admin', async () => {
    await expectRevert(
      this.contract.decreaseTotalSupply(_100(), {from: user}),
      'Ownable: caller is not the owner'
    )
  });

  it('should fail to decrease total supply if ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);

    await expectRevert(
      this.contract.decreaseTotalSupply(_100(), {from: admin}),
      'ECOSYSTEM_PAUSED'
    );
  });

  /********************************
   * Admin Deposits
   */

  it('should deposit underlying from admin', async () => {
    await setBalanceFor(this.underlyingToken, admin, _100());
    await setApproval(this.underlyingToken, admin, this.contract.address);
    const receipt = await this.contract.depositUnderlying(_100(), {from: admin});
    expectEvent(
      receipt,
      'Transfer',
      {from: admin, to: this.contract.address, value: _100()}
    );
    (await this.underlyingToken.balanceOf(this.contract.address)).should.be.bignumber.equal(_100())
  });

  it('should fail to deposit underlying from non-admin', async () => {
    await expectRevert(
      this.contract.depositUnderlying(_100(), {from: user}),
      'Ownable: caller is not the owner'
    )
  });

  it('should fail to deposit underlying if ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);

    await expectRevert(
      this.contract.depositUnderlying(_100(), {from: admin}),
      'ECOSYSTEM_PAUSED'
    );
  });

  /********************************
   * Admin Withdrawals
   */

  it('should withdraw underlying from admin', async () => {
    await setBalanceFor(this.underlyingToken, this.contract.address, _100());
    const receipt = await this.contract.withdrawUnderlying(_100(), {from: admin});
    expectEvent(
      receipt,
      'Transfer',
      {from: this.contract.address, to: admin, value: _100()}
    );
    (await this.underlyingToken.balanceOf(this.contract.address)).should.be.bignumber.equal(_0())
  });

  it('should fail to withdraw underlying from non-admin', async () => {
    await expectRevert(
      this.contract.withdrawUnderlying(_100(), {from: user}),
      'Ownable: caller is not the owner'
    )
  });

  it('should fail to withdraw underlying if ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);

    await expectRevert(
      this.contract.withdrawUnderlying(_100(), {from: admin}),
      'ECOSYSTEM_PAUSED'
    );
  });
});