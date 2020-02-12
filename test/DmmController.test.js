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
  doDmmControllerBeforeEach,
  setApproval,
  setBalanceFor,
  mint,
  pauseEcosystem,
} = require('./helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, user] = accounts;

describe('DmmController', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doDmmControllerBeforeEach(this, contract, web3);
  });

  it('should transfer ownership', async () => {
    const receipt = await this.controller.transferOwnership(user, {from: admin});
    expectEvent(receipt, 'OwnershipTransferred', {previousOwner: admin, newOwner: user})
  });

  it('should get blacklistable', async () => {
    expect(await this.controller.blacklistable()).equals(this.blacklistable.address)
  });

  it('should add market', async () => {
    // TODO
  });

  it('should enable market', async () => {
    // TODO
  });

  it('should disable market', async () => {
    // TODO
  });

  it('should set new interest rate interface', async () => {
    // TODO
  });

  it('should set new min collateralization', async () => {
    // TODO
  });

  it('should set new min reserve ratio', async () => {
    // TODO
  });

  it('should increase total supply', async () => {
    // TODO
  });

  it('should decrease total supply', async () => {
    // TODO
  });

  it('should allow admin to withdraw underlying', async () => {
    // TODO
  });

  it('should allow admin to deposit underlying', async () => {
    // TODO
  });

  it('should not allow non-admin to deposit underlying', async () => {
    // TODO
  });

  it('should not allow non-admin to deposit underlying', async () => {
    // TODO
  });

  it('should get interest rate using token ID', async () => {
    // TODO
  });

  it('should get interest rate using token address', async () => {
    // TODO
  });

  it('should get exchange rate using underlying token address', async () => {
    // TODO
  });

  it('should get exchange rate using DMM token address', async () => {
    // TODO
  });

  it('should get is market enabled', async () => {
    // TODO
  });

  it('should get DMM token ID from DMM token address', async () => {
    // TODO
  });

});