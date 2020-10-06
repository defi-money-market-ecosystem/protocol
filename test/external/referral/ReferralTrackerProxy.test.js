const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectRevert, expectEvent, send, balance} = require('@openzeppelin/test-helpers');

const {
  snapshotChain,
  resetChain,
  doDmmTokenBeforeEach,
  setApproval,
  _001,
  _1,
  _10000,
  _0,
  signMessage,
} = require('../../helpers/DmmTokenTestHelpers');


// Use the different accounts, which are unlocked and funded with Ether
const [admin, user, otherUser, referrer] = accounts;

// Create a contract object from a compilation artifact
const ReferralTrackerProxy = contract.fromArtifact('ReferralTrackerProxy');
const ReferralTrackerImplV1 = contract.fromArtifact('ReferralTrackerImplV1');

describe('ReferralTrackerProxy', () => {
  let proxy = null;
  let snapshotId = null;

  before(async () => {
    this.admin = admin;
    this.user = user;

    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);

    const WETH = contract.fromArtifact('WETHMock');
    this.weth = await WETH.new({from: this.admin});

    await doDmmTokenBeforeEach(this, contract, web3);

    this.symbol = "mETH";
    this.name = "DMM: ETH";
    this.decimals = new BN(18);
    this.minMintAmount = _001();
    this.minRedeemAmount = _001();
    this.totalSupply = _10000();

    const DmmEther = contract.fromArtifact('DmmEther');
    this.mETH = await DmmEther.new(
      this.weth.address,
      this.symbol,
      this.name,
      this.decimals,
      this.minMintAmount,
      this.minRedeemAmount,
      this.totalSupply,
      this.controller.address,
      {from: this.admin},
    );

    const implementation = await ReferralTrackerImplV1.new();

    proxy = await ReferralTrackerProxy.new(
      implementation.address,
      admin,
      admin,
      this.weth.address,
      {from: admin},
    );

    proxy = await contract.fromArtifact('ReferralTrackerImplV1', proxy.address);

    (await proxy.weth()).should.be.eq(this.weth.address);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    snapshotId = await resetChain(provider, snapshotId);
  });

  it('should mint properly using ETH proxy', async () => {
    const amount = _1();
    const receipt = await proxy.mintViaEther(referrer, this.mETH.address, {from: user, value: amount});
    expectEvent(
      receipt,
      'ProxyMint',
      {
        referrer,
        minter: user,
        receiver: user,
        amount: amount,
        underlyingAmount: amount,
      }
    );

    ((await this.mETH.balanceOf(user))).should.be.bignumber.equal(amount);
    ((await balance.current(proxy.address))).should.be.bignumber.equal(_0());
    ((await this.mETH.balanceOf(proxy.address))).should.be.bignumber.equal(_0());
  });

  it('should mint properly using the proxy', async () => {
    await setApproval(this.dai, user, proxy.address);
    // The user's balance is set in the beforeEach to be _10000()
    ((await this.dai.balanceOf(user))).should.be.bignumber.equal(_10000());

    const receipt = await proxy.mint(referrer, this.mDAI.address, _10000(), {from: user});
    expectEvent(
      receipt,
      'ProxyMint',
      {
        referrer,
        minter: user,
        receiver: user,
        amount: _10000(),
        underlyingAmount: _10000(),
      }
    );

    ((await this.mDAI.balanceOf(user))).should.be.bignumber.equal(_10000());
    ((await this.dai.balanceOf(user))).should.be.bignumber.equal(_0());

    ((await this.dai.balanceOf(proxy.address))).should.be.bignumber.equal(_0());
    ((await this.mDAI.balanceOf(proxy.address))).should.be.bignumber.equal(_0());
  });

  it('should redeem properly using the proxy', async () => {
    await setApproval(this.dai, user, proxy.address);
    await setApproval(this.mDAI, otherUser, proxy.address);

    // The user's balance is set in the beforeEach to be _10000()
    ((await this.dai.balanceOf(user))).should.be.bignumber.equal(_10000());
    await proxy.mint(referrer, this.mDAI.address, _10000(), {from: user});

    await this.mDAI.transfer(otherUser, _10000(), {from: user});

    const receipt = await proxy.redeem(referrer, this.mDAI.address, _10000(), {from: otherUser});
    expectEvent(
      receipt,
      'ProxyRedeem',
      {
        referrer,
        redeemer: otherUser,
        receiver: otherUser,
        amount: _10000(),
        underlyingAmount: _10000(),
      }
    );

    ((await this.mDAI.balanceOf(otherUser))).should.be.bignumber.equal(_0());
    ((await this.dai.balanceOf(otherUser))).should.be.bignumber.equal(_10000());

    ((await this.mDAI.balanceOf(user))).should.be.bignumber.equal(_0());
    ((await this.dai.balanceOf(user))).should.be.bignumber.equal(_0());

    ((await this.dai.balanceOf(proxy.address))).should.be.bignumber.equal(_0());
    ((await this.mDAI.balanceOf(proxy.address))).should.be.bignumber.equal(_0());
  });

  it('should mint via gasless request properly using the proxy', async () => {
    await send.ether(this.admin, this.wallet.address, _1());
    const amount = _10000();
    await this.dai.transfer(this.wallet.address, amount, {from: user});
    // The approval is set on the mDAI contract, because it pulls the funds in for gasless requests - not the proxy
    await setApproval(this.dai, this.wallet.address, this.mDAI.address);

    // The user's balance is set in the beforeEach to be amount
    ((await this.dai.balanceOf(this.wallet.address))).should.be.bignumber.equal(amount);

    const feeAmount = _0();
    const feeRecipientAddress = constants.ZERO_ADDRESS;
    const typeHash = await this.mDAI.MINT_TYPE_HASH();
    const signature = await encodeHashAndSign(
      this,
      typeHash,
      this.wallet.address,
      otherUser,
      _0(),
      _0(),
      amount,
      feeAmount,
      feeRecipientAddress,
    )

    const receipt = await proxy.mintFromGaslessRequest(
      referrer,
      this.mDAI.address,
      this.wallet.address,
      otherUser,
      _0(),
      _0(),
      amount,
      feeAmount,
      feeRecipientAddress,
      signature.v,
      signature.r,
      signature.s,
      {from: otherUser}
    );
    expectEvent(
      receipt,
      'ProxyMint',
      {
        referrer,
        minter: this.wallet.address,
        receiver: otherUser,
        amount: amount,
        underlyingAmount: amount,
      }
    );

    ((await this.mDAI.balanceOf(this.wallet.address))).should.be.bignumber.equal(_0());
    ((await this.dai.balanceOf(this.wallet.address))).should.be.bignumber.equal(_0());

    ((await this.mDAI.balanceOf(otherUser))).should.be.bignumber.equal(amount);
    ((await this.dai.balanceOf(otherUser))).should.be.bignumber.equal(_0());

    ((await this.dai.balanceOf(proxy.address))).should.be.bignumber.equal(_0());
    ((await this.mDAI.balanceOf(proxy.address))).should.be.bignumber.equal(_0());
  });

  it('should redeem via gasless request properly using the proxy', async () => {
    await setApproval(this.dai, user, proxy.address);
    await setApproval(this.mDAI, otherUser, proxy.address);

    // The user's balance is set in the beforeEach to be _10000()
    ((await this.dai.balanceOf(user))).should.be.bignumber.equal(_10000());
    await proxy.mint(referrer, this.mDAI.address, _10000(), {from: user});

    const amount = _10000();
    const feeAmount = _0();
    await this.mDAI.transfer(this.wallet.address, amount, {from: user});

    const feeRecipientAddress = constants.ZERO_ADDRESS;
    const typeHash = await this.mDAI.REDEEM_TYPE_HASH();
    const signature = await encodeHashAndSign(this, typeHash, this.wallet.address, otherUser, _0(), _0(), amount, feeAmount, feeRecipientAddress)

    const receipt = await proxy.redeemFromGaslessRequest(
      referrer,
      this.mDAI.address,
      this.wallet.address,
      otherUser,
      _0(),
      _0(),
      amount,
      feeAmount,
      feeRecipientAddress,
      signature.v,
      signature.r,
      signature.s,
      {from: otherUser}
    );
    expectEvent(
      receipt,
      'ProxyRedeem',
      {
        referrer,
        redeemer: this.wallet.address,
        receiver: otherUser,
        amount: _10000(),
        underlyingAmount: _10000(),
      }
    );

    ((await this.mDAI.balanceOf(otherUser))).should.be.bignumber.equal(_0());
    ((await this.dai.balanceOf(otherUser))).should.be.bignumber.equal(_10000());

    ((await this.mDAI.balanceOf(user))).should.be.bignumber.equal(_0());
    ((await this.dai.balanceOf(user))).should.be.bignumber.equal(_0());

    ((await this.dai.balanceOf(proxy.address))).should.be.bignumber.equal(_0());
    ((await this.mDAI.balanceOf(proxy.address))).should.be.bignumber.equal(_0());
  });

  /** ********************
   * Utility Functions
   */

  const encodeHashAndSign = async (thisInstance, typeHash, ownerAddress, otherAddress, nonce, expiry, amount, feeAmount, feeRecipientAddress) => {
    const domainSeparator = await thisInstance.mDAI.domainSeparator();
    const messageHash = web3.utils.sha3(
      web3.eth.abi.encodeParameters(
        [
          'bytes32',
          'address',
          'address',
          'uint',
          'uint',
          'uint',
          'uint',
          'address',
        ],
        [
          typeHash,
          ownerAddress,
          otherAddress,
          nonce.toString(),
          expiry.toString(),
          amount.toString(),
          feeAmount.toString(),
          feeRecipientAddress.toString(),
        ]
      )
    );
    const digest = web3.utils.soliditySha3('\x19\x01', domainSeparator, messageHash);
    return signMessage(thisInstance, digest);
  };
});
