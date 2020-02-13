const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  BN,
  constants,
  expectEvent,
  expectRevert,
  send,
  time,
} = require('@openzeppelin/test-helpers');
const {
  _0,
  _1,
  _24,
  _24_5,
  _25,
  _10000,
  blacklistUser,
  disableMarkets,
  doDmmTokenBeforeEach,
  encodeHashAndSign,
  expectMint,
  expectOffChainRequestValidated,
  pauseEcosystem,
  setupWallet,
} = require('./helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, recipient, user, otherFeeRecipient] = accounts;

describe('DmmToken.GaslessMint', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);
    await doDmmTokenBeforeEach(this, contract, web3);

    this.send = send;
    await setupWallet(this, user);
  });

  it('should mint using gasless request', async () => {
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _0();
    const feeRecipient = constants.ZERO_ADDRESS;
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    const receipt = await this.contract.mintFromGaslessRequest(
      this.wallet.address,
      recipient,
      nonce,
      expiry,
      amount,
      feeAmount,
      feeRecipient,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    expectMint(this, receipt, this.wallet.address, this.contract.address);
    expectOffChainRequestValidated(this, receipt, feeRecipient, feeAmount, nonce, expiry);

    // Nonce should be incremented
    (await this.contract.nonceOf(this.wallet.address)).should.be.bignumber.equal(new BN(1));
  });

  it('should mint using gasless request with fees', async () => {
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _1();
    const feeRecipient = otherFeeRecipient;
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    const receipt = await this.contract.mintFromGaslessRequest(
      this.wallet.address,
      recipient,
      nonce,
      expiry,
      amount,
      feeAmount,
      feeRecipient,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    expectMint(this, receipt, this.wallet.address, this.contract.address, _25());
    expectOffChainRequestValidated(this, receipt, feeRecipient, feeAmount, nonce, expiry);

    (await this.contract.balanceOf(recipient)).should.be.bignumber.equal(_24());
    (await this.contract.balanceOf(feeRecipient)).should.be.bignumber.equal(_1());
    (await this.contract.nonceOf(this.wallet.address)).should.be.bignumber.equal(new BN(1));
  });

  it('should mint using gasless request consecutively', async () => {
    const typeHash = await this.contract.MINT_TYPE_HASH();
    let nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _0();
    const feeRecipient = constants.ZERO_ADDRESS;
    let signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    let receipt = await this.contract.mintFromGaslessRequest(
      this.wallet.address,
      recipient,
      nonce,
      expiry,
      amount,
      feeAmount,
      feeRecipient,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    expectMint(this, receipt, this.wallet.address, this.contract.address);
    expectOffChainRequestValidated(this, receipt, feeRecipient, feeAmount, nonce, expiry);

    // Request 2

    nonce = new BN(1);
    signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    receipt = await this.contract.mintFromGaslessRequest(
      this.wallet.address,
      recipient,
      nonce,
      expiry,
      amount,
      feeAmount,
      feeRecipient,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    expectMint(this, receipt, this.wallet.address, this.contract.address);
    expectOffChainRequestValidated(this, receipt, feeRecipient, feeAmount, nonce, expiry);

    // Nonce should be incremented twice
    (await this.contract.nonceOf(this.wallet.address)).should.be.bignumber.equal(new BN(2));
  });

  it('should not mint using gasless request when msg.sender blacklisted', async () => {
    await blacklistUser(this.blacklistable, user, admin);
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _0();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'BLACKLISTED'
    );
  });

  it('should not mint using gasless request when owner blacklisted', async () => {
    await blacklistUser(this.blacklistable, this.wallet.address, admin);
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _0();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'BLACKLISTED'
    );
  });

  it('should not mint using gasless request when fee recipient blacklisted', async () => {
    await blacklistUser(this.blacklistable, otherFeeRecipient, admin);
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _0();
    const feeRecipient = otherFeeRecipient;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'BLACKLISTED'
    );
  });

  it('should not mint using gasless request when ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _0();
    const feeRecipient = otherFeeRecipient;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'ECOSYSTEM_PAUSED'
    );
  });

  it('should not mint using gasless request when actual mint amount is too small', async () => {
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _24_5();
    const feeRecipient = otherFeeRecipient;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'INSUFFICIENT_MINT_AMOUNT'
    );
  });

  it('should not mint using gasless request when fee is too large', async () => {
    const nonce = _0();
    const expiry = _0();
    const amount = _1();
    const feeAmount = _25();
    const feeRecipient = otherFeeRecipient;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'FEE_TOO_LARGE'
    );
  });

  it('should not mint using gasless request when fee recipient is 0x0 address', async () => {
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'INVALID_FEE_ADDRESS'
    );
  });

  it('should not mint using gasless request when signature is invalid', async () => {
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x0000000000000000000000000000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000000000000000000000000000',
        {from: user}
      ),
      'INVALID_SIGNATURE'
    );
  });

  it('should not mint using gasless request when signature is expired', async () => {
    const latestTimestamp = await time.latest();
    const nonce = _0();
    const expiry = latestTimestamp.sub(new BN(100));
    const amount = _25();
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'REQUEST_EXPIRED'
    );
  });

  it('should not mint using gasless request when nonce is invalid', async () => {
    const nonce = new BN('24832');
    const expiry = _0();
    const amount = _25();
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'INVALID_NONCE'
    );
  });

  it('should not mint using gasless request when owner is 0x0 address', async () => {
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        constants.ZERO_ADDRESS,
        recipient,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'CANNOT_MINT_FROM_ZERO_ADDRESS'
    );
  });

  it('should not mint using gasless request when recipient is 0x0 address', async () => {
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        constants.ZERO_ADDRESS,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'CANNOT_MINT_TO_ZERO_ADDRESS'
    );
  });

  it('should not mint using gasless request when market is disabled', async () => {
    await disableMarkets(this.controller, admin);
    const nonce = _0();
    const expiry = _0();
    const amount = _25();
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.MINT_TYPE_HASH();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.mintFromGaslessRequest(
        this.wallet.address,
        constants.ZERO_ADDRESS,
        nonce,
        expiry,
        amount,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'MARKET_DISABLED'
    );
  });

});