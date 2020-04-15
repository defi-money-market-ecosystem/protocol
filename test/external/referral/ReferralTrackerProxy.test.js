const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectRevert, expectEvent} = require('@openzeppelin/test-helpers');

const {doDmmTokenBeforeEach, setApproval, _10000, _0} = require('../../helpers/DmmTokenTestHelpers');


// Use the different accounts, which are unlocked and funded with Ether
const [admin, user, otherUser] = accounts;

// Create a contract object from a compilation artifact
const ReferralTrackerProxy = contract.fromArtifact('ReferralTrackerProxy');

describe('ReferralTrackerProxy', () => {
  let proxy = null;

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;

    await doDmmTokenBeforeEach(this, contract, web3);

    proxy = await ReferralTrackerProxy.new({from: admin});
  });

  it('should mint properly using the proxy', async () => {
    await setApproval(this.dai, user, proxy.address);
    // The user's balance is set in the beforeEach to be _10000()
    ((await this.dai.balanceOf(user))).should.be.bignumber.equal(_10000());

    const receipt = await proxy.mint(this.mDAI.address, _10000(), {from: user});
    expectEvent(
      receipt,
      'ProxyMint',
      {
        minter: user,
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
    await proxy.mint(this.mDAI.address, _10000(), {from: user});

    await this.mDAI.transfer(otherUser, _10000(), {from: user});

    const receipt = await proxy.redeem(this.mDAI.address, _10000(), {from: otherUser});
    expectEvent(
      receipt,
      'ProxyRedeem',
      {
        redeemer: otherUser,
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
});
