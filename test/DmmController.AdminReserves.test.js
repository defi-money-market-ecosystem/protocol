const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  BN,
  constants,
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const {
  _0,
  _001,
  _00625,
  _05,
  _1,
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

describe('DmmController.AdminReserves', async () => {

  const ownableError = 'Ownable: caller is not the owner';
  const defaultDmmTokenId = new BN('1');

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doDmmControllerBeforeEach(this, contract, web3);
  });

  it('should increase total supply', async () => {
    await addDaiMarket();
    const receipt = await this.controller.increaseTotalSupply(defaultDmmTokenId, _100(), {from: admin});
    expectEvent(
      receipt,
      'TotalSupplyIncreased',
      {oldTotalSupply: _10000(), newTotalSupply: _100().add(_10000())}
    );
  });

  it('should not increase total supply if not owner', async () => {
    await addDaiMarket();
    await expectRevert(
      this.controller.increaseTotalSupply(defaultDmmTokenId, _100(), {from: user}),
      ownableError,
    );
  });

  it('should not increase total supply if ecosystem paused', async () => {
    await addDaiMarket();
    await pauseEcosystem(this.controller, admin);
    await expectRevert(
      this.controller.increaseTotalSupply(defaultDmmTokenId, _100(), {from: admin}),
      "ECOSYSTEM_PAUSED",
    );
  });

  it('should not increase total supply if there is insufficient collateral', async () => {
    await addDaiMarket();
    await this.offChainAssetValuator.setCollateralValue(_1());
    await expectRevert(
      this.controller.increaseTotalSupply(defaultDmmTokenId, _100(), {from: admin}),
      "INSUFFICIENT_COLLATERAL",
    );
  });

  it('should decrease total supply', async () => {
    await addDaiMarket();
    const receipt = await this.controller.decreaseTotalSupply(defaultDmmTokenId, _100(), {from: admin});
    expectEvent(
      receipt,
      'TotalSupplyDecreased',
      {oldTotalSupply: _10000(), newTotalSupply: _10000().sub(_100())}
    );
  });

  it('should not decrease total supply if not owner', async () => {
    await addDaiMarket();
    await expectRevert(
      this.controller.decreaseTotalSupply(defaultDmmTokenId, _100(), {from: user}),
      ownableError,
    );
  });

  it('should not decrease total supply if ecosystem is paused', async () => {
    await addDaiMarket();
    await pauseEcosystem(this.controller, admin);
    await expectRevert(
      this.controller.decreaseTotalSupply(defaultDmmTokenId, _100(), {from: admin}),
      "ECOSYSTEM_PAUSED",
    );
  });

  it('should not decrease total supply if there is too much active supply', async () => {
    await addDaiMarket();
    await expectRevert(
      this.controller.decreaseTotalSupply(defaultDmmTokenId, _10000().add(_10000()), {from: admin}),
      "TOO_MUCH_ACTIVE_SUPPLY",
    );
  });

  it('should allow admin to withdraw underlying', async () => {
    await addDaiMarket();
    const dmmTokenAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId);
    const dmmToken = contract.fromArtifact('DmmToken', dmmTokenAddress);
    await mint(this.dai, dmmToken, user, _100());

    const receipt = await this.controller.adminWithdrawFunds(defaultDmmTokenId, _1(), {from: admin});
    expectEvent(
      receipt,
      'AdminWithdraw',
      {receiver: admin, amount: _1()} // the controller is the admin of the token
    );

    (await this.dai.balanceOf(admin)).should.be.bignumber.equals(_1());
  });

  it('should not allow admin to withdraw underlying when there is insufficient leftover reserves', async () => {
    await addDaiMarket();
    const dmmTokenAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId);
    const dmmToken = contract.fromArtifact('DmmToken', dmmTokenAddress);
    await mint(this.dai, dmmToken, user, _1());

    await expectRevert(
      this.controller.adminWithdrawFunds(defaultDmmTokenId, _1(), {from: admin}),
      'INSUFFICIENT_LEFTOVER_RESERVES',
    );
  });

  it('should not allow non-admin to withdraw underlying', async () => {
    await addDaiMarket();
    const dmmTokenAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId);
    const dmmToken = contract.fromArtifact('DmmToken', dmmTokenAddress);
    await mint(this.dai, dmmToken, user, _100());

    await expectRevert(
      this.controller.adminWithdrawFunds(defaultDmmTokenId, _1(), {from: user}),
      ownableError,
    );
  });

  it('should allow admin to deposit underlying', async () => {
    const amount = _100();
    await addDaiMarket();
    await setBalanceFor(this.dai, admin, amount);
    await setApproval(this.dai, admin, this.controller.address);

    const receipt = await this.controller.adminDepositFunds(defaultDmmTokenId, amount, {from: admin});
    expectEvent(
      receipt,
      'AdminDeposit',
      {sender: admin, amount: amount}
    );

    const dmmTokenAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId);

    (await this.dai.balanceOf(admin)).should.be.bignumber.equals(_0());
    (await this.dai.balanceOf(dmmTokenAddress)).should.be.bignumber.equals(amount);
  });

  it('should not allow non-admin to deposit underlying', async () => {
    const amount = _100();
    await addDaiMarket();
    await setBalanceFor(this.dai, admin, amount);
    await setApproval(this.dai, admin, this.controller.address);

    await expectRevert(
      this.controller.adminDepositFunds(defaultDmmTokenId, amount, {from: user}),
      ownableError,
    );
  });

  /**********************
   * Utility Functions
   */

  const addDaiMarket = async () => {
    const receipt = await this.controller.addMarket(
      this.dai.address,
      "mDAI",
      "DMM: DAI",
      18,
      _001(),
      _001(),
      _10000(),
      {from: admin}
    );

    expectEvent(
      receipt,
      'MarketAdded',
      {dmmTokenId: defaultDmmTokenId, underlyingToken: this.dai.address}
    );
  };

});