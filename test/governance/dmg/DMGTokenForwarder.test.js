const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const {
  _0,
  _1,
  _100,
} = require('../../helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, beneficiary, user] = accounts;

describe('DMGTokenForwarder', async () => {

  const invalidBeneficiaryErrorMsg = 'DMGTokenForwarder: INVALID_BENEFICIARY'
  const DMGTokenForwarder = contract.fromArtifact('DMGTokenForwarder')
  const ERC20Mock = contract.fromArtifact('ERC20Mock')

  beforeEach(async () => {
    this.admin = admin;
    this.beneficiary = beneficiary;
    this.forwarder = await DMGTokenForwarder.new(this.beneficiary, {from: admin});
    this.token = await ERC20Mock.new();
    await this.token.setBalance(this.forwarder.address, _100());
  });

  it('Should forward tokens when sent from beneficiary', async () => {
    const receipt = await this.forwarder.release(user, this.token.address, _1(), {from: beneficiary});
    expectEvent(receipt, 'Released', {to: user, amount: _1()});
    const balance = await this.token.balanceOf(user);

    const releasedAmount = await this.forwarder.tokenToReleasedAmountMap(this.token.address);
    (releasedAmount).should.be.bignumber.equal(_1());

    (balance).should.be.bignumber.equal(_1());
  })

  it('Should not forward tokens when not sent from beneficiary', async () => {
    const tx1 = this.forwarder.release(user, this.token.address, _1(), {from: admin});
    await expectRevert(tx1, invalidBeneficiaryErrorMsg);

    const tx2 = this.forwarder.release(user, this.token.address, _1(), {from: user});
    await expectRevert(tx2, invalidBeneficiaryErrorMsg);

    const releasedAmount = await this.forwarder.tokenToReleasedAmountMap(this.token.address);
    (releasedAmount).should.be.bignumber.equal(_0());

    const balance = await this.token.balanceOf(user);
    (balance).should.be.bignumber.equal(_0());
  })

  it('Should set beneficiary when sent from beneficiary', async () => {
    const receipt = await this.forwarder.setBeneficiary(admin, {from: beneficiary});
    expectEvent(receipt, 'BeneficiaryChanged');
  })

  it('Should not set beneficiary when not sent from beneficiary', async () => {
    await expectRevert(this.forwarder.setBeneficiary(user, {from: admin}), invalidBeneficiaryErrorMsg)
    await expectRevert(this.forwarder.setBeneficiary(user, {from: user}), invalidBeneficiaryErrorMsg)
  })
});