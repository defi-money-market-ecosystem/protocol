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
  doBeforeEach,
  setApproval,
  setBalanceFor,
  mint,
  pauseEcosystem,
} = require('./helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, user] = accounts;

describe('DmmToken.Admin', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doBeforeEach(this, contract, web3);
  });

  /********************************
   * Increase the Total Supply
   */

  it('should increase total supply if sent by admin', async () => {
    const receipt = await this.contract.increaseTotalSupply(_100(), {from: admin});
    expectEvent(receipt, 'TotalSupplyIncreased', {oldTotalSupply: _10000(), newTotalSupply: _10000().add(_100())});
    (await this.contract.balanceOf(this.contract.address)).should.be.bignumber.equal(_10000().add(_100()));
  });


});