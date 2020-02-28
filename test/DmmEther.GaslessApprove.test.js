const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  BN,
  constants,
  expectRevert,
  send,
  time,
} = require('@openzeppelin/test-helpers');
const {
  _0,
  _1,
  _25,
  _10000,
  blacklistUser,
  disableMarkets,
  doDmmEtherBeforeEach,
  encodePermitHashAndSign,
  expectApprove,
  expectOffChainRequestValidated,
  mint,
  pauseEcosystem,
  setupWallet,
} = require('./helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, recipient, user, otherFeeRecipient] = accounts;

describe('DmmEther.GaslessApprove', async () => {

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);
    await doDmmEtherBeforeEach(this, contract, web3, accounts[accounts.length - 1]);

    this.send = send;
    await setupWallet(this, user);
    await mint(this.underlyingToken, this.contract, this.wallet.address, _25());
  });

  it('should permit using gasless request', async () => {
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _0();
    const feeRecipient = constants.ZERO_ADDRESS;
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    const receipt = await this.contract.permit(
      this.wallet.address,
      recipient,
      nonce,
      expiry,
      approve,
      feeAmount,
      feeRecipient,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    expectApprove(this, receipt, recipient, true);
    expectOffChainRequestValidated(this, receipt, feeRecipient, feeAmount, nonce, expiry);

    // Nonce should be incremented
    (await this.contract.nonceOf(this.wallet.address)).should.be.bignumber.equal(new BN(1));
  });

  it('should permit using gasless request with fees', async () => {
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _1();
    const feeRecipient = otherFeeRecipient;
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    const receipt = await this.contract.permit(
      this.wallet.address,
      recipient,
      nonce,
      expiry,
      approve,
      feeAmount,
      feeRecipient,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    expectApprove(this, receipt, recipient, true);
    expectOffChainRequestValidated(this, receipt, feeRecipient, feeAmount, nonce, expiry);

    (await this.contract.balanceOf(feeRecipient)).should.be.bignumber.equal(_1());
    (await this.contract.nonceOf(this.wallet.address)).should.be.bignumber.equal(new BN(1));
  });

  it('should permit using gasless request consecutively', async () => {
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    let nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _0();
    const feeRecipient = constants.ZERO_ADDRESS;
    let signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    let receipt = await this.contract.permit(
      this.wallet.address,
      recipient,
      nonce,
      expiry,
      approve,
      feeAmount,
      feeRecipient,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    expectApprove(this, receipt, recipient, true);
    expectOffChainRequestValidated(this, receipt, feeRecipient, feeAmount, nonce, expiry);

    // Request 2

    nonce = new BN(1);
    signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    receipt = await this.contract.permit(
      this.wallet.address,
      recipient,
      nonce,
      expiry,
      approve,
      feeAmount,
      feeRecipient,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    expectApprove(this, receipt, recipient, true);
    expectOffChainRequestValidated(this, receipt, feeRecipient, feeAmount, nonce, expiry);

    // Nonce should be incremented twice
    (await this.contract.nonceOf(this.wallet.address)).should.be.bignumber.equal(new BN(2));
  });

  it('should permit using gasless request when market is disabled', async () => {
    await disableMarkets(this.controller, admin);
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _1();
    const feeRecipient = otherFeeRecipient;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);

    const receipt = await this.contract.permit(
      this.wallet.address,
      recipient,
      nonce,
      expiry,
      approve,
      feeAmount,
      feeRecipient,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
      {from: user}
    );

    expectApprove(this, receipt, recipient, true);
    expectOffChainRequestValidated(this, receipt, feeRecipient, feeAmount, nonce, expiry);

    (await this.contract.balanceOf(feeRecipient)).should.be.bignumber.equal(_1());
    (await this.contract.nonceOf(this.wallet.address)).should.be.bignumber.equal(new BN(1));
  });

  it('should not permit using gasless request when msg.sender blacklisted', async () => {
    await blacklistUser(this.blacklistable, user, admin);
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _0();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        approve,
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

  it('should not permit using gasless request when owner blacklisted', async () => {
    await blacklistUser(this.blacklistable, this.wallet.address, admin);
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _0();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        approve,
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

  it('should not permit using gasless request when fee recipient blacklisted', async () => {
    await blacklistUser(this.blacklistable, otherFeeRecipient, admin);
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _0();
    const feeRecipient = otherFeeRecipient;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        approve,
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

  it('should not permit using gasless request when ecosystem is paused', async () => {
    await pauseEcosystem(this.controller, admin);
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _0();
    const feeRecipient = otherFeeRecipient;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        approve,
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

  it('should not permit using gasless request when fee is too large', async () => {
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _10000();
    const feeRecipient = otherFeeRecipient;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        approve,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'INSUFFICIENT_BALANCE_FOR_FEE'
    );
  });

  it('should not permit using gasless request when fee recipient is 0x0 address', async () => {
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        approve,
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

  it('should not permit using gasless request when signature is invalid', async () => {
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        approve,
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

  it('should not permit using gasless request when signature is expired', async () => {
    const latestTimestamp = await time.latest();
    const nonce = _0();
    const expiry = latestTimestamp.sub(new BN(100));
    const approve = true;
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        approve,
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

  it('should not permit using gasless request when nonce is invalid', async () => {
    const nonce = new BN('24832');
    const expiry = _0();
    const approve = true;
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        recipient,
        nonce,
        expiry,
        approve,
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

  it('should not permit using gasless request when owner is 0x0 address', async () => {
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        constants.ZERO_ADDRESS,
        recipient,
        nonce,
        expiry,
        approve,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'CANNOT_APPROVE_FROM_ZERO_ADDRESS'
    );
  });

  it('should not permit using gasless request when recipient is 0x0 address', async () => {
    const nonce = _0();
    const expiry = _0();
    const approve = true;
    const feeAmount = _1();
    const feeRecipient = constants.ZERO_ADDRESS;
    const typeHash = await this.contract.PERMIT_TYPE_HASH();
    const signedMessage = await encodePermitHashAndSign(this, typeHash, recipient, nonce, expiry, approve, feeAmount, feeRecipient);
    await expectRevert(
      this.contract.permit(
        this.wallet.address,
        constants.ZERO_ADDRESS,
        nonce,
        expiry,
        approve,
        feeAmount,
        feeRecipient,
        new BN(signedMessage.v),
        '0x' + signedMessage.r.toString('hex'),
        '0x' + signedMessage.s.toString('hex'),
        {from: user}
      ),
      'CANNOT_APPROVE_TO_ZERO_ADDRESS'
    );
  });

});