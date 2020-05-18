const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  BN,
  constants,
  expectEvent,
  send,
  time,
} = require('@openzeppelin/test-helpers');
const {
  _0,
  _1,
  _100,
  _250000000,
  doDmgTokenBeforeEach,
  signMessage,
} = require('../../helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, user, other, recipient, spender, randomDelegate] = accounts;

describe('DMG.UserInteractions', async () => {

  const ownableError = 'Ownable: caller is not the owner';
  const defaultDmmTokenId = new BN('1');

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);
    await doDmgTokenBeforeEach(this, contract, web3);
  });

  it('should verify basic info after deployment', async () => {
    await expectEvent.inConstruction(
      this.dmgToken,
      'Transfer',
      {from: constants.ZERO_ADDRESS, to: admin, value: _250000000()}
    );

    const totalSupply = await this.dmgToken.totalSupply();
    (totalSupply).should.be.bignumber.equal(_250000000());

    const adminBalance = await this.dmgToken.balanceOf(admin);
    (adminBalance).should.be.bignumber.equal(_250000000());
  });

  it('should transfer funds properly', async () => {
    const receipt = await this.dmgToken.transfer(user, _100(), {from: admin});
    expectEvent(
      receipt,
      'Transfer',
      {from: admin, to: user, value: _100()}
    );

    const adminBalance = await this.dmgToken.balanceOf(admin);
    (adminBalance).should.be.bignumber.equal(_250000000().sub(_100()));

    const userBalance = await this.dmgToken.balanceOf(user);
    (userBalance).should.be.bignumber.equal(_100());

    const votes = await this.dmgToken.getCurrentVotes(user);
    (votes).should.be.bignumber.equal(_0());
  });

  it('should burn funds properly', async () => {
    await this.dmgToken.transfer(user, _100(), {from: admin});

    const receipt = await this.dmgToken.burn(_100(), {from: user});
    expectEvent(
      receipt,
      'Transfer',
      {from: user, to: constants.ZERO_ADDRESS, value: _100()}
    );

    const userBalance = await this.dmgToken.balanceOf(user);
    (userBalance).should.be.bignumber.equal(_0());

    // Funds are burned, as opposed to sent to the zero address to effectively do the same thing.
    const burnBalance = await this.dmgToken.balanceOf(constants.ZERO_ADDRESS);
    (burnBalance).should.be.bignumber.equal(_0());

    const votes = await this.dmgToken.getCurrentVotes(user);
    (votes).should.be.bignumber.equal(_0());
  })

  it('should burn funds properly when delegates are involved', async () => {
    await this.dmgToken.transfer(user, _100(), {from: admin});

    const delegateReceipt = await this.dmgToken.delegate(other, {from: user});
    expectEvent(
      delegateReceipt,
      'DelegateChanged',
      {
        delegator: user,
        fromDelegate: constants.ZERO_ADDRESS,
        toDelegate: other,
      }
    );

    const otherVotes = await this.dmgToken.getCurrentVotes(other);
    (otherVotes).should.be.bignumber.equal(_100());

    const burnReceipt = await this.dmgToken.burn(_100(), {from: user});
    expectEvent(
      burnReceipt,
      'Transfer',
      {from: user, to: constants.ZERO_ADDRESS, value: _100()}
    );
    expectEvent(
      burnReceipt,
      'DelegateVotesChanged',
      {delegate: other, previousBalance: _100(), newBalance: _0()}
    )

    const userBalance = await this.dmgToken.balanceOf(user);
    (userBalance).should.be.bignumber.equal(_0());

    // Funds are burned, as opposed to sent to the zero address to effectively do the same thing.
    const burnBalance = await this.dmgToken.balanceOf(constants.ZERO_ADDRESS);
    (burnBalance).should.be.bignumber.equal(_0());

    const userVotes = await this.dmgToken.getCurrentVotes(user);
    (userVotes).should.be.bignumber.equal(_0());
  });

  it('should execute a gasless transfer', async () => {
    await this.dmgToken.transfer(this.wallet.address, _100(), {from: admin});
    await this.dmgToken.delegate(other, {from: recipient})
    await send.ether(admin, this.wallet.address, _1());

    await this.dmgToken.delegate(randomDelegate, {from: this.wallet.address});

    const typeHash = await this.dmgToken.TRANSFER_TYPE_HASH();
    const nonce = _0();
    const expiry = (await time.latest()).add(_100());
    const amount = _100();
    const signedMessage = await encodeHashAndSign(this, typeHash, recipient, nonce, expiry, amount);
    const receipt = await this.dmgToken.transferBySig(
      recipient,
      amount,
      nonce,
      expiry,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    expectEvent(
      receipt,
      'Transfer',
      {from: this.wallet.address, to: recipient, value: amount}
    );

    // Nonce should be incremented
    (await this.dmgToken.nonceOf(this.wallet.address)).should.be.bignumber.equal(new BN(1));

    // Votes should have propagated to recipient's delegate
    (await this.dmgToken.getCurrentVotes(randomDelegate)).should.be.bignumber.equal(_0());
    (await this.dmgToken.getCurrentVotes(other)).should.be.bignumber.equal(amount);
  })

  it('should execute a gasless approval', async () => {
    await this.dmgToken.transfer(this.wallet.address, _100(), {from: admin});

    const typeHash = await this.dmgToken.APPROVE_TYPE_HASH();
    const nonce = _0();
    const expiry = (await time.latest()).add(_100());
    const amount = constants.MAX_UINT256;
    const signedMessage = await encodeHashAndSign(this, typeHash, spender, nonce, expiry, amount);
    const receipt = await this.dmgToken.approveBySig(
      spender,
      amount,
      nonce,
      expiry,
      new BN(signedMessage.v),
      '0x' + signedMessage.r.toString('hex'),
      '0x' + signedMessage.s.toString('hex'),
    );

    const MAX_UINT_128 = (new BN(2).pow(new BN(128))).sub(new BN(1))
    expectEvent(
      receipt,
      'Approval',
      {owner: this.wallet.address, spender: spender, value: MAX_UINT_128}
    );

    // Nonce should be incremented
    (await this.dmgToken.nonceOf(this.wallet.address)).should.be.bignumber.equal(new BN(1));
  });

  /** ********************
   * Utility Functions
   */

  const encodeHashAndSign = async (thisInstance, typeHash, otherAddress, nonce, expiry, amount) => {
    const domainSeparator = await thisInstance.dmgToken.domainSeparator();
    const messageHash = web3.utils.sha3(
      web3.eth.abi.encodeParameters(
        [
          'bytes32',
          'address',
          'uint',
          'uint',
          'uint',
        ],
        [
          typeHash,
          otherAddress,
          amount.toString(),
          nonce.toString(),
          expiry.toString(),
        ]
      )
    );
    const digest = web3.utils.soliditySha3('\x19\x01', domainSeparator, messageHash);
    return signMessage(thisInstance, digest);
  };

});