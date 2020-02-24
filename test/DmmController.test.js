const {accounts, contract, web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
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

describe('DmmController', async () => {

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

  it('should set new collateral valuator', async () => {
    const receipt = await this.controller.setCollateralValuator(constants.ZERO_ADDRESS, {from: admin});
    expectEvent(
      receipt,
      'CollateralValuatorChanged',
      {
        previousCollateralValuator: this.collateralValuator.address,
        newCollateralValuator: constants.ZERO_ADDRESS
      },
    );
  });

  it('should not set new collateral valuator if not owner', async () => {
    await expectRevert(
      this.controller.setCollateralValuator(constants.ZERO_ADDRESS, {from: user}),
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
    await this.collateralValuator.setCollateralValue(_1());
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
      {admin: admin, amount: _1()} // the controller is the admin of the token
    );
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
      {admin: admin, amount: amount}
    );
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

  it('should get total collateralization correctly when using tokens w/ diff precisions', async () => {
    // This test is great because USDC and DAI have different precisions - 18 vs 6.
    await addDaiMarket();
    await addUsdcMarket();
    // We added 10,000 worth of both markets, which equates $20,000 * 1e18. Our collateral's value is 10m * 1e18.
    // (10,000,000 * 1e18 / $20,000 * 1e18)

    const dmmDaiAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(new BN('1'));
    const dmmDai = contract.fromArtifact('DmmToken', dmmDaiAddress);

    const dmmUsdcAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(new BN('2'));
    const dmmUsdc = contract.fromArtifact('DmmToken', dmmUsdcAddress);

    const _10m = new BN('10000000').mul(_1());

    const mDaiTotalSupply = await dmmDai.totalSupply();
    const mUsdcTotalSupply = (await dmmUsdc.totalSupply()).mul(new BN('1000000000000')); // standardize decimals

    let totalValue = new BN('0');
    totalValue = totalValue.add((mDaiTotalSupply).mul(_1()).div(await dmmDai.getCurrentExchangeRate()));
    totalValue = totalValue.add((mUsdcTotalSupply).mul(_1()).div(await dmmUsdc.getCurrentExchangeRate()));
    const expectedCollateralization = _10m.mul(_1()).div(totalValue);

    const totalCollateralization = await this.controller.getTotalCollateralization();
    (totalCollateralization).should.be.bignumber.equals(expectedCollateralization);
  });

  it('should get active collateralization correctly when using tokens w/ diff precisions', async () => {
    // This test is great because USDC and DAI have different precisions - 18 vs 6.
    await addDaiMarket();
    await addUsdcMarket();
    // We added 10,000 worth of both markets, which equates $20,000 * 1e18. Our collateral's value is 10m * 1e18.
    // (10,000,000 * 1e18 / $20,000 * 1e18)

    // Before we mint, the collateralization is 0.
    const activeCollateralizationBeforeMint = await this.controller.getActiveCollateralization();
    (activeCollateralizationBeforeMint).should.be.bignumber.equals(_0());

    const dmmDaiAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(new BN('1'));
    const dmmDai = contract.fromArtifact('DmmToken', dmmDaiAddress);

    const dmmUsdcAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(new BN('2'));
    const dmmUsdc = contract.fromArtifact('DmmToken', dmmUsdcAddress);

    const rawMintAmount1 = await mint(this.dai, dmmDai, user, _100());
    const usdc100 = new BN('100000000');
    const rawMintAmount2 = await mint(this.usdc, dmmUsdc, user, usdc100);

    const mintAmount1 = rawMintAmount1.mul(_1()).div(await dmmDai.getCurrentExchangeRate());
    // USDC is missing 12 decimals of precision, so add it
    const mintAmount2 = rawMintAmount2.mul(new BN('1000000000000')).mul(_1()).div(await dmmUsdc.getCurrentExchangeRate());

    const tenMillion = new BN('10000000000000000000000000');
    const collateralization = tenMillion.mul(_1()).div(mintAmount1.add(mintAmount2));

    // Before we mint, the collateralization is 0.
    const activeCollateralizationAfterMint = await this.controller.getActiveCollateralization();
    (activeCollateralizationAfterMint).should.be.bignumber.equals(collateralization);
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

  const addUsdcMarket = async () => {
    const receipt = await this.controller.addMarket(
      this.usdc.address,
      "mUSDC",
      "DMM: USDC",
      6,
      new BN('1'),
      new BN('1'),
      new BN('10000000000'), // 10,000
      {from: admin}
    );

    expectEvent(
      receipt,
      'MarketAdded',
      {dmmTokenId: defaultDmmTokenId.add(new BN('1')), underlyingToken: this.usdc.address}
    );
  };

});