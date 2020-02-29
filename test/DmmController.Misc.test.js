const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
const {expect} = require('chai');
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

describe('DmmController.Misc', async () => {

  const ownableError = 'Ownable: caller is not the owner';
  const defaultDmmTokenId = new BN('1');

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
    await addDaiMarket();
  });

  it('should enable and disable market', async () => {
    await addDaiMarket();

    await expectRevert(
      this.controller.enableMarket(defaultDmmTokenId, {from: admin}),
      'MARKET_ALREADY_ENABLED',
    );
    const disableReceipt = await this.controller.disableMarket(defaultDmmTokenId, {from: admin});
    expectEvent(
      disableReceipt,
      'DisableMarket',
      {dmmTokenId: defaultDmmTokenId},
    );


    await expectRevert(
      this.controller.disableMarket(defaultDmmTokenId, {from: admin}),
      'MARKET_ALREADY_DISABLED',
    );
    const enableReceipt = await this.controller.enableMarket(defaultDmmTokenId, {from: admin});
    expectEvent(
      enableReceipt,
      'EnableMarket',
      {dmmTokenId: defaultDmmTokenId},
    );
  });

  it('should not enable and disable market if not owner', async () => {
    await addDaiMarket();

    await expectRevert(
      this.controller.disableMarket(defaultDmmTokenId, {from: user}),
      ownableError,
    );

    await expectRevert(
      this.controller.enableMarket(defaultDmmTokenId, {from: user}),
      ownableError,
    );
  });

  it('should set new interest rate interface', async () => {
    const receipt = await this.controller.setInterestRateInterface(constants.ZERO_ADDRESS, {from: admin});
    expectEvent(
      receipt,
      'InterestRateInterfaceChanged',
      {
        previousInterestRateInterface: this.interestRateInterface.address,
        newInterestRateInterface: constants.ZERO_ADDRESS
      },
    );
  });

  it('should not set new interest rate interface if not owner', async () => {
    await expectRevert(
      this.controller.setInterestRateInterface(constants.ZERO_ADDRESS, {from: user}),
      ownableError
    );
  });

  it('should set new asset valuator', async () => {
    const receipt = await this.controller.setOffChainAssetValuator(constants.ZERO_ADDRESS, {from: admin});
    expectEvent(
      receipt,
      'OffChainAssetValuatorChanged',
      {
        previousOffChainAssetValuator: this.offChainAssetValuator.address,
        newOffChainAssetValuator: constants.ZERO_ADDRESS
      },
    );
  });

  it('should not set new asset valuator if not owner', async () => {
    await expectRevert(
      this.controller.setOffChainAssetValuator(constants.ZERO_ADDRESS, {from: user}),
      ownableError
    );
  });

  it('should set new currency valuator', async () => {
    const receipt = await this.controller.setOffChainCurrencyValuator(constants.ZERO_ADDRESS, {from: admin});
    expectEvent(
      receipt,
      'OffChainCurrencyValuatorChanged',
      {
        previousOffChainCurrencyValuator: this.offChainCurrencyValuator.address,
        newOffChainCurrencyValuator: constants.ZERO_ADDRESS
      },
    );
  });

  it('should not set new currency valuator if not owner', async () => {
    await expectRevert(
      this.controller.setOffChainCurrencyValuator(constants.ZERO_ADDRESS, {from: user}),
      ownableError
    );
  });

  it('should set new underlying token valuator', async () => {
    const receipt = await this.controller.setUnderlyingTokenValuator(constants.ZERO_ADDRESS, {from: admin});
    expectEvent(
      receipt,
      'UnderlyingTokenValuatorChanged',
      {
        previousUnderlyingTokenValuator: this.underlyingTokenValuator.address,
        newUnderlyingTokenValuator: constants.ZERO_ADDRESS
      },
    );
  });

  it('should not set new underlying token valuator if not owner', async () => {
    await expectRevert(
      this.controller.setUnderlyingTokenValuator(constants.ZERO_ADDRESS, {from: user}),
      ownableError
    );
  });

  it('should set new min collateralization', async () => {
    const receipt = await this.controller.setMinCollateralization(_05(), {from: admin});
    expectEvent(
      receipt,
      'MinCollateralizationChanged',
      {
        previousMinCollateralization: _1(),
        newMinCollateralization: _05(),
      },
    );
  });

  it('should not set new min collateralization if not owner', async () => {
    await expectRevert(
      this.controller.setMinCollateralization(_05(), {from: user}),
      ownableError
    );
  });

  it('should set new min reserve ratio', async () => {
    const receipt = await this.controller.setMinReserveRatio(_1(), {from: admin});
    expectEvent(
      receipt,
      'MinReserveRatioChanged',
      {
        previousMinReserveRatio: _05(),
        newMinReserveRatio: _1(),
      },
    );
  });

  it('should not set new min reserve ratio if not owner', async () => {
    await expectRevert(
      this.controller.setMinReserveRatio(_1(), {from: user}),
      ownableError
    );
  });

  it('should get interest rate using underlying token address', async () => {
    await addDaiMarket();
    (await this.controller.getInterestRateByUnderlyingTokenAddress(this.dai.address)).should.be.bignumber.equal(_00625());
  });

  it('should get interest rate using DMM token address', async () => {
    await addDaiMarket();
    const dmmTokenAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId);
    (await this.controller.getInterestRateByDmmTokenAddress(dmmTokenAddress)).should.be.bignumber.equal(_00625());
  });

  it('should get interest rate using DMM token ID', async () => {
    await addDaiMarket();
    (await this.controller.getInterestRateByDmmTokenId(defaultDmmTokenId)).should.be.bignumber.equal(_00625());
  });

  it('should get exchange rate using DMM token address', async () => {
    await addDaiMarket();
    const dmmTokenAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId);
    (await this.controller.getInterestRateByDmmTokenAddress(dmmTokenAddress)).should.be.bignumber.equal(_00625());
  });

  it('should get exchange rate using DMM token address', async () => {
    await addDaiMarket();
    const dmmTokenAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId);
    (await this.controller.getExchangeRate(dmmTokenAddress)).should.be.bignumber.equal(_1());
  });

  it('should get is market enabled', async () => {
    await addDaiMarket();
    expect(await this.controller.isMarketEnabledByDmmTokenId(defaultDmmTokenId)).equals(true);

    const dmmTokenAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId);
    expect(await this.controller.isMarketEnabledByDmmTokenAddress(dmmTokenAddress)).equals(true);
  });

  it('should get DMM token ID from DMM token address', async () => {
    await addDaiMarket();
    const dmmTokenAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId);
    (await this.controller.getTokenIdFromDmmTokenAddress(dmmTokenAddress)).should.be.bignumber.equals(defaultDmmTokenId);
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