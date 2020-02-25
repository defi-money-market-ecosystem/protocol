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

describe('DmmController.Collateralization', async () => {

  const ownableError = 'Ownable: caller is not the owner';
  const defaultDmmTokenId = new BN('1');

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doDmmControllerBeforeEach(this, contract, web3);
  });

  it('should get total collateralization correctly when using tokens w/ diff precisions', async () => {
    // This test is great because USDC and DAI have different precisions - 18 vs 6.
    await addDaiMarket();
    await addUsdcMarket();
    // We added 10,000 worth of both markets, which equates $20,000 * 1e18. Our collateral's value is 10m * 1e18.
    // Total Collateralization is defined as basically (total held assets / liabilities)
    // This equates to (10,000,000 + 20,000) / (20,000)

    const dmmDaiAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(new BN('1'));
    const dmmDai = contract.fromArtifact('DmmToken', dmmDaiAddress);

    const dmmUsdcAddress = await this.controller.dmmTokenIdToDmmTokenAddressMap(new BN('2'));
    const dmmUsdc = contract.fromArtifact('DmmToken', dmmUsdcAddress);

    const _10m = new BN('10000000').mul(_1());

    const daiValueOfTotalSupply = (await dmmDai.totalSupply()).mul(await dmmDai.getCurrentExchangeRate()).div(_1());
    let usdcValueOfTotalSupply = (await dmmUsdc.totalSupply()).mul(await dmmUsdc.getCurrentExchangeRate()).div(_1());

    // Standardize decimals since USDC only has 6 --> transform to have 18
    usdcValueOfTotalSupply = usdcValueOfTotalSupply.mul(new BN('1000000000000'));

    let totalValue = daiValueOfTotalSupply.add(usdcValueOfTotalSupply);
    const expectedCollateralization = (_10m.add(totalValue)).mul(_1()).div(totalValue);

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

    await mint(this.dai, dmmDai, user, _100());

    const usdc100 = new BN('100000000');
    await mint(this.usdc, dmmUsdc, user, usdc100);

    const daiExchangeRate = await dmmDai.getCurrentExchangeRate();
    const usdcExchangeRate = await dmmUsdc.getCurrentExchangeRate();

    const mintAmount1 = (await dmmDai.activeSupply()).mul(daiExchangeRate).div(_1());

    // USDC is missing 12 decimals of precision, so add it
    const mintAmount2 = (await dmmUsdc.activeSupply()).mul(usdcExchangeRate).div(_1()).mul(new BN('1000000000000'));

    const tenMillion = new BN('10000000000000000000000000');
    const underlyingBalance = _100().mul(new BN('2'));
    const expectedCollateralization = (tenMillion.add(underlyingBalance)).mul(_1()).div(mintAmount1.add(mintAmount2));

    // Before we mint, the collateralization is 0.
    const activeCollateralizationAfterMint = await this.controller.getActiveCollateralization();
    (activeCollateralizationAfterMint).should.be.bignumber.equals(expectedCollateralization);
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