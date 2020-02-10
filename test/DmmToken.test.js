/**
 * This file is responsible for testing the admin functions for the DMM token.
 */

const {accounts, contract, web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  BN,
  balance,
  constants,
  should,
  expectEvent,
  expectRevert,
  send,
  time,
} = require('@openzeppelin/test-helpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, deployer, user] = accounts;

// Create a contract object from a compilation artifact
const DmmBlacklistable = contract.fromArtifact('DmmBlacklistable');
const DmmControllerMock = contract.fromArtifact('DmmControllerMock');
const DmmToken = contract.fromArtifact('DmmToken');
const DmmTokenLibrary = contract.fromArtifact('DmmTokenLibrary');
const ERC20Mock = contract.fromArtifact('ERC20Mock');
const SafeERC20 = contract.fromArtifact('SafeERC20');
const SafeMath = contract.fromArtifact('SafeMath');

const _0 = new BN('0');
const _1 = new BN('1000000000000000000');
const _25 = new BN('25000000000000000000');
const _50 = new BN('50000000000000000000');
const _75 = new BN('75000000000000000000');
const _100 = new BN('100000000000000000000');
const _10000 = new BN('10000000000000000000000');

const secondsInYear = new BN('31536000');

const _realInterestRate = new BN('62500000000000000');

describe('DmmToken', async () => {

  beforeEach(async () => {
    await ERC20Mock.detectNetwork();
    await DmmToken.detectNetwork();
    await DmmTokenLibrary.detectNetwork();

    const safeERC20 = await SafeERC20.new();
    const safeMath = await SafeMath.new();
    const dmmTokenLibrary = await DmmTokenLibrary.new();

    await ERC20Mock.link("SafeMath", safeMath.address);

    await DmmToken.link("SafeERC20", safeERC20.address);
    await DmmToken.link("SafeMath", safeMath.address);
    await DmmToken.link("DmmTokenLibrary", dmmTokenLibrary.address);

    this.blacklistable = await DmmBlacklistable.new();
    this.didApproveUnderlying = false;
    this.didApproveDmm = false;

    this.underlyingToken = await ERC20Mock.new();
    this.interestRate = _0;
    this.controller = await DmmControllerMock.new(
      this.blacklistable.address,
      this.underlyingToken.address,
      this.interestRate,
      {from: admin}
    );

    await this.underlyingToken.setBalance(user, _10000);

    this.symbol = "dmmDAI";
    this.name = "DMM: DAI";
    this.decimals = new BN(18);
    this.minMintAmount = _1;
    this.minRedeemAmount = _1;
    this.totalSupply = _10000;

    this.contract = await DmmToken.new(
      this.symbol,
      this.name,
      this.decimals,
      this.minMintAmount,
      this.minRedeemAmount,
      this.totalSupply,
      this.controller.address,
      {from: admin}
    );
  });

  /********************************
   * Misc Getters
   */

  it('should get symbol', async () => {
    expect(await this.contract.symbol()).to.equal(this.symbol);
  });

  it('should get name', async () => {
    expect(await this.contract.name()).to.equal(this.name);
  });

  it('should get decimals', async () => {
    (await this.contract.decimals()).should.be.bignumber.equal(this.decimals);
  });

  it('should get minMintAmount', async () => {
    (await this.contract.minMintAmount()).should.be.bignumber.equal(this.minMintAmount);
  });

  it('should get minRedeemAmount', async () => {
    (await this.contract.minRedeemAmount()).should.be.bignumber.equal(this.minRedeemAmount);
  });

  it('should get totalSupply', async () => {
    (await this.contract.totalSupply()).should.be.bignumber.equal(this.totalSupply);
  });

  it('should revert when ETH is sent to contract', async () => {
    await expectRevert(
      send.ether(user, this.contract.address, new BN('10000000000000000')),
      "NO_DEFAULT_FUNCTION"
    )
  });

  it('should get the blacklistable contract', async () => {
    const blacklistable = await this.contract.blacklistable();
    expect(blacklistable).to.equal(this.blacklistable.address);
  });

  it('should get the pausable contract', async () => {
    const pausable = await this.contract.pausable();
    expect(pausable).to.equal(this.controller.address);
  });

  it('should get the default nonce for any address', async () => {
    (await this.contract.nonceOf(deployer)).should.be.bignumber.equal(_0);
    (await this.contract.nonceOf(user)).should.be.bignumber.equal(_0);
    (await this.contract.nonceOf(admin)).should.be.bignumber.equal(_0);
  });

  /********************************
   * Active Supply
   */

  it('should get initial active supply', async () => {
    const activeSupply = await this.contract.activeSupply();
    (activeSupply).should.be.bignumber.equal(new BN('0'));
  });

  it('should get active supply after mint', async () => {
    await mint(_100);
    const activeSupply = await this.contract.activeSupply();
    (activeSupply).should.be.bignumber.equal(_100);
  });

  it('should get active supply after mint & redeem', async () => {
    await mint(_100);
    await redeem(_25);
    const activeSupply = await this.contract.activeSupply();
    (activeSupply).should.be.bignumber.equal(_75);
  });

  /********************************
   * Increase the Total Supply
   */

  it('should increase total supply if sent by admin', async () => {
    const receipt = await this.contract.increaseTotalSupply(_100, {from: admin});
    expectEvent(receipt, 'TotalSupplyIncreased', {oldTotalSupply: _10000, newTotalSupply: _10000.add(_100)});
    (await this.contract.balanceOf(this.contract.address)).should.be.bignumber.equal(_10000.add(_100));
  });

  it('should fail to increase total supply if not sent by admin', async () => {
    await expectRevert(
      this.contract.increaseTotalSupply(_100, {from: user}),
      'Ownable: caller is not the owner'
    )
  });

  it('should fail to increase total supply if ecosystem is paused', async () => {
    expect(await this.controller.isPaused()).to.equal(false);
    await this.controller.pause({from: admin});
    expect(await this.controller.isPaused()).to.equal(true);

    await expectRevert(
      this.contract.increaseTotalSupply(_100, {from: admin}),
      'ECOSYSTEM_PAUSED'
    )
  });

  /********************************
   * Decrease the Total Supply
   */

  it('should decrease total supply if sent by admin', async () => {
    const receipt = await this.contract.decreaseTotalSupply(_100, {from: admin});
    expectEvent(
      receipt,
      'TotalSupplyDecreased',
      {oldTotalSupply: _10000, newTotalSupply: _10000.sub(_100)}
    );
    (await this.contract.balanceOf(this.contract.address)).should.be.bignumber.equal(_10000.sub(_100));
  });

  it('should fail to decrease total supply if there is too much active supply', async () => {
    await mint(_10000);
    await expectRevert(
      this.contract.decreaseTotalSupply(_100, {from: admin}),
      'TOO_MUCH_ACTIVE_SUPPLY'
    )
  });

  it('should fail to decrease total supply if not sent by admin', async () => {
    await expectRevert(
      this.contract.decreaseTotalSupply(_100, {from: user}),
      'Ownable: caller is not the owner'
    )
  });

  it('should fail to decrease total supply if ecosystem is paused', async () => {
    expect(await this.controller.isPaused()).to.equal(false);
    await this.controller.pause({from: admin});
    expect(await this.controller.isPaused()).to.equal(true);

    await expectRevert(
      this.contract.decreaseTotalSupply(_100, {from: admin}),
      'ECOSYSTEM_PAUSED'
    );
  });

  /********************************
   * Admin Deposits
   */

  it('should deposit underlying from admin', async () => {
    await setBalanceFor(admin, _100);
    await setApprovalFor(admin);
    const receipt = await this.contract.depositUnderlying(_100, {from: admin});
    expectEvent(
      receipt,
      'Transfer',
      {from: admin, to: this.contract.address, value: _100}
    );
    (await this.underlyingToken.balanceOf(this.contract.address)).should.be.bignumber.equal(_100)
  });

  it('should fail to deposit underlying from non-admin', async () => {
    await expectRevert(
      this.contract.depositUnderlying(_100, {from: user}),
      'Ownable: caller is not the owner'
    )
  });

  it('should fail to deposit underlying if ecosystem is paused', async () => {
    expect(await this.controller.isPaused()).to.equal(false);
    await this.controller.pause({from: admin});
    expect(await this.controller.isPaused()).to.equal(true);

    await expectRevert(
      this.contract.depositUnderlying(_100, {from: admin}),
      'ECOSYSTEM_PAUSED'
    );
  });

  /********************************
   * Admin Withdrawals
   */

  it('should withdraw underlying from admin', async () => {
    await setBalanceFor(this.contract.address, _100);
    const receipt = await this.contract.withdrawUnderlying(_100, {from: admin});
    expectEvent(
      receipt,
      'Transfer',
      {from: this.contract.address, to: admin, value: _100}
    );
    (await this.underlyingToken.balanceOf(this.contract.address)).should.be.bignumber.equal(_0)
  });

  it('should fail to withdraw underlying from non-admin', async () => {
    await expectRevert(
      this.contract.withdrawUnderlying(_100, {from: user}),
      'Ownable: caller is not the owner'
    )
  });

  it('should fail to withdraw underlying if ecosystem is paused', async () => {
    expect(await this.controller.isPaused()).to.equal(false);
    await this.controller.pause({from: admin});
    expect(await this.controller.isPaused()).to.equal(true);

    await expectRevert(
      this.contract.withdrawUnderlying(_100, {from: admin}),
      'ECOSYSTEM_PAUSED'
    );
  });

  /********************************
   * Exchange Rate
   */

  it('should get current exchange rate & timestamp and update properly over 1 year', async () => {
    await setRealInterestRate();
    const latestTimestamp = await time.latest();
    (await this.contract.currentExchangeRate()).should.be.bignumber.equal(_1);
    (await this.contract.exchangeRateLastUpdatedTimestamp()).should.be.bignumber.equal(latestTimestamp);

    const timePassed = time.duration.days(365);
    await time.increase(timePassed);

    // Minting updates the timestamp at which the exchange_rate was last updated
    await mint(_1);

    (await this.contract.currentExchangeRate()).should.be.bignumber.equal(_1.add(_realInterestRate));
    (await this.contract.exchangeRateLastUpdatedTimestamp()).should.be.bignumber.equal(latestTimestamp.add(timePassed));
  });

  it('should get current exchange rate & timestamp and update properly over awkward time', async () => {
    await setRealInterestRate();
    const latestTimestamp = await time.latest();
    // TODO - change this to be >= 1 and <= 5 seconds passing since 1
    (await this.contract.currentExchangeRate()).should.be.bignumber.equal(_1);
    (await this.contract.exchangeRateLastUpdatedTimestamp()).should.be.bignumber.equal(latestTimestamp);

    const timePassed = time.duration.days(180);
    await time.increase(timePassed);

    // Minting updates the timestamp at which the exchange_rate was last updated
    await mint(_1);

    const _1YearSeconds = time.duration.days(365);

    const interestRateToApply = _realInterestRate.mul(timePassed).div(_1YearSeconds);
    (await this.contract.currentExchangeRate()).should.be.bignumber.equal(_1.add(interestRateToApply));
    (await this.contract.exchangeRateLastUpdatedTimestamp()).should.be.bignumber.equal(latestTimestamp.add(timePassed));
  });

  /********************************
   * Utility Functions
   */

  const mint = async (amount, expectedError) => {
    if (!this.didApproveUnderlying) {
      await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: user});
      this.didApproveUnderlying = true;
    }
    if (expectedError) {
      await expectRevert.unspecified(
        this.contract.mint(amount, {from: user}),
        expectedError
      )
    } else {
      await this.contract.mint(amount, {from: user});
    }
  };

  const redeem = async (amount, expectedError) => {
    if (!this.didApproveDmm) {
      await this.contract.approve(this.contract.address, constants.MAX_UINT256, {from: user});
      this.didApproveDmm = true;
    }
    if (expectedError) {
      await expectRevert(
        this.contract.redeem(amount, {from: user}),
        expectedError
      )
    } else {
      await this.contract.redeem(amount, {from: user});
    }
  };

  const setRealInterestRate = async () => {
    this.interestRate = _realInterestRate;
    await this.controller.setInterestRate(_realInterestRate);
  };

  const setBalanceFor = async (address, amount) => {
    const receipt = await this.underlyingToken.setBalance(address, amount);
    expectEvent(receipt, 'Transfer')
  };

  const setApprovalFor = async (address) => {
    const receipt = await this.underlyingToken.approve(this.contract.address, constants.MAX_UINT256, {from: address});
    expectEvent(
      receipt,
      'Approval',
      {owner: address, spender: this.contract.address, value: constants.MAX_UINT256}
    )
  };

});
