const {accounts, contract, web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  BN,
  expectRevert,
  send,
  time,
} = require('@openzeppelin/test-helpers');
const {
  _0,
  _1,
  _25,
  _75,
  _100,
  doBeforeEach,
  mint,
  redeem,
  setRealInterestRateOnController
} = require('./helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, deployer, user] = accounts;

// Create a contract object from a compilation artifact

const secondsInYear = new BN('31536000');

describe('DmmToken.Misc', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doBeforeEach(this, contract, web3);
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
    (await this.contract.nonceOf(deployer)).should.be.bignumber.equal(_0());
    (await this.contract.nonceOf(user)).should.be.bignumber.equal(_0());
    (await this.contract.nonceOf(admin)).should.be.bignumber.equal(_0());
  });

  /********************************
   * Active Supply
   */

  it('should get initial active supply', async () => {
    const activeSupply = await this.contract.activeSupply();
    (activeSupply).should.be.bignumber.equal(_0());
  });

  it('should get active supply after mint', async () => {
    await mint(this.underlyingToken, this.contract, user, _100());
    const activeSupply = await this.contract.activeSupply();
    (activeSupply).should.be.bignumber.equal(_100());
  });

  it('should get active supply after mint & redeem', async () => {
    await mint(this.underlyingToken, this.contract, user, _100());
    await redeem(this.contract, user, _25());
    const activeSupply = await this.contract.activeSupply();
    (activeSupply).should.be.bignumber.equal(_75());
  });

  /********************************
   * Exchange Rate
   */

  it('should get current exchange rate & timestamp and update properly over 1 year', async () => {
    let latestTimestamp = await time.latest();
    (await this.contract.currentExchangeRate()).should.be.bignumber.equal(_1());
    (await this.contract.exchangeRateLastUpdatedTimestamp()).should.be.bignumber.equal(latestTimestamp);

    const originalTimestamp = latestTimestamp;
    await setRealInterestRateOnController(this);

    const timePassed = time.duration.days(365);
    await time.increase(timePassed);

    // Minting updates the timestamp at which the exchange_rate was last updated
    await mint(this.underlyingToken, this.contract, user, _100());
    latestTimestamp = await time.latest(); // Get the current timestamp after minting

    const timeElapsed = latestTimestamp.sub(originalTimestamp);
    const interestAccrued = timeElapsed.mul(this.interestRate).div(secondsInYear);
    (await this.contract.currentExchangeRate()).should.be.bignumber.equal(_1().add(interestAccrued));
    (await this.contract.exchangeRateLastUpdatedTimestamp()).should.be.bignumber.equal(latestTimestamp);
  });

  it('should get current exchange rate & timestamp and update properly over awkward time', async () => {
    let latestTimestamp = await time.latest();
    (await this.contract.currentExchangeRate()).should.be.bignumber.equal(_1());
    (await this.contract.exchangeRateLastUpdatedTimestamp()).should.be.bignumber.equal(latestTimestamp);

    const originalTimestamp = latestTimestamp;
    await setRealInterestRateOnController(this);

    const timePassed = time.duration.days(180);
    await time.increase(timePassed);

    // Minting updates the timestamp at which the exchange_rate was last updated
    await mint(this.underlyingToken, this.contract, user, _100());
    latestTimestamp = await time.latest(); // Get the current timestamp after minting

    const timeElapsed = latestTimestamp.sub(originalTimestamp);
    const interestAccrued = timeElapsed.mul(this.interestRate).div(secondsInYear);
    (await this.contract.currentExchangeRate()).should.be.bignumber.equal(_1().add(interestAccrued));
    (await this.contract.exchangeRateLastUpdatedTimestamp()).should.be.bignumber.equal(latestTimestamp);
  });

});