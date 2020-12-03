const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {expectRevert, expectEvent, BN} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1} = require('../../helpers/DmmTokenTestHelpers');
const {doAssetIntroductionV1BeforeEach, createNFTs} = require('../../helpers/AssetIntroductionHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, user2, owner, other] = accounts;

describe('AssetIntroducerV1.ERC721', () => {
  const ownerError = 'ERC721Token: NOT_OWNER_OR_NOT_APPROVED_OR_NOT_OPERATOR'
  let snapshotId;
  before(async () => {
    this.admin = admin;
    this.guardian = guardian;
    this.owner = owner;
    this.user = user;
    this.user2 = user2;

    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);

    await doAssetIntroductionV1BeforeEach(this, contract, web3);

    await createNFTs(this);

    snapshotId = await snapshotChain(provider);
  });

  beforeEach(async () => {
    await resetChain(provider, snapshotId);
  });

  it('supportsInterface: should resolve to true for ERC-721 and false for others', async () => {
    (await this.assetIntroducer.supportsInterface('0x80ac58cd')).should.be.eq(true);
    (await this.assetIntroducer.supportsInterface('0xffffffff')).should.be.eq(false);
  });

  it('tokenURI: should get tokenURI for valid token', async () => {
    const baseURI = await this.assetIntroducer.baseURI();
    (await this.assetIntroducer.tokenURI(this.tokenIds[0])).should.be.eq(baseURI + this.tokenIds[0]);
  });

  it('safeTransferFrom: should work for token sent by owner', async () => {
    const result = await this.assetIntroducer.safeTransferFrom(user, user2, this.tokenIds[0], {from: user});
    expectEvent(
      result,
      'Transfer',
      {from: user, to: user2, tokenId: this.tokenIds[0]}
    );
    (await this.assetIntroducer.ownerOf(this.tokenIds[0])).should.be.eq(user2);
  });

  it('safeTransferFrom: should work for token sent by an operator of specific token', async () => {
    let result = await this.assetIntroducer.approve(admin, this.tokenIds[0], {from: user});
    expectEvent(
      result,
      'Approval',
      {owner: user, operator: admin, tokenId: this.tokenIds[0]},
    );
    (await this.assetIntroducer.getApproved(this.tokenIds[0])).should.be.eq(admin);

    result = await this.assetIntroducer.safeTransferFrom(user, user2, this.tokenIds[0], {from: admin});
    expectEvent(
      result,
      'Transfer',
      {from: user, to: user2, tokenId: this.tokenIds[0]}
    );
    (await this.assetIntroducer.ownerOf(this.tokenIds[0])).should.be.eq(user2);
  });

  it('safeTransferFrom: should work for token sent by an operator approved for all', async () => {
    let result = await this.assetIntroducer.setApprovalForAll(admin, true, {from: user});
    expectEvent(
      result,
      'ApprovalForAll',
      {owner: user, operator: admin, approved: true},
    );
    (await this.assetIntroducer.isApprovedForAll(user, admin)).should.be.eq(true);

    result = await this.assetIntroducer.safeTransferFrom(user, user2, this.tokenIds[0], {from: admin});
    expectEvent(
      result,
      'Transfer',
      {from: user, to: user2, tokenId: this.tokenIds[0]}
    );
    (await this.assetIntroducer.ownerOf(this.tokenIds[0])).should.be.eq(user2);
  });

  it('safeTransferFrom: should work for token sent by OpenSea operator', async () => {
    await this.openSeaProxyRegistry.setProxy(user, admin);
    const result = await this.assetIntroducer.safeTransferFrom(user, user2, this.tokenIds[0], {from: admin});
    expectEvent(
      result,
      'Transfer',
      {from: user, to: user2, tokenId: this.tokenIds[0]}
    );
    (await this.assetIntroducer.ownerOf(this.tokenIds[0])).should.be.eq(user2);
  });

  it('safeTransferFrom: should not work when not sent token sent by owner', async () => {
    const result = this.assetIntroducer.safeTransferFrom(user, admin, this.tokenIds[0], {from: guardian});
    await expectRevert(result, ownerError);
  });

  it('safeTransferFrom: should not work when sent to unsupported contract', async () => {
    const result = this.assetIntroducer.safeTransferFrom(user, this.dmmController.address, this.tokenIds[0], {from: user});
    await expectRevert(result, 'ERC721TokenLib::_verifyCanReceiveTokens: UNABLE_TO_RECEIVE_TOKEN');
  });

  it('safeTransferFrom: should not work when sent to self', async () => {
    const result = this.assetIntroducer.safeTransferFrom(user, this.assetIntroducer.address, this.tokenIds[0], {from: user});
    await expectRevert(result, 'ERC721TokenLib::_verifyCanReceiveTokens: UNABLE_TO_RECEIVE_TOKEN');
  });

  it('balanceOf: should work for different owners', async () => {
    (await this.assetIntroducer.balanceOf(user)).should.be.bignumber.eq(new BN('3'));
    (await this.assetIntroducer.balanceOf(user2)).should.be.bignumber.eq(new BN('2'));
    (await this.assetIntroducer.balanceOf(other)).should.be.bignumber.eq(new BN('0'));
  });

  it('totalSupply: should work for different owners', async () => {
    (await this.assetIntroducer.totalSupply()).should.be.bignumber.eq(new BN('7'));
  });

  it('tokenByIndex: should work for different indices', async () => {
    for (let i = 0; i < this.tokenIds.length; i++) {
      (await this.assetIntroducer.getAssetIntroducerByTokenId(this.tokenIds[i])).serialNumber.should.be.bignumber.eq(new BN(i + 1));
    }
  });

  it('tokenByIndex: should fail if index is oob', async () => {
    const result = this.assetIntroducer.tokenByIndex(this.tokenIds.length);
    await expectRevert(result, 'ERC721TokenLib::tokenByIndex: INVALID_INDEX');
  });

  it('tokenOfOwnerByIndex: should work for different indices', async () => {
    (await this.assetIntroducer.tokenOfOwnerByIndex(user, 0)).should.be.bignumber.eq(this.tokenIds[0]);
    (await this.assetIntroducer.tokenOfOwnerByIndex(user, 1)).should.be.bignumber.eq(this.tokenIds[1]);
    (await this.assetIntroducer.tokenOfOwnerByIndex(user, 2)).should.be.bignumber.eq(this.tokenIds[2]);

    (await this.assetIntroducer.tokenOfOwnerByIndex(user2, 0)).should.be.bignumber.eq(this.tokenIds[3]);
    (await this.assetIntroducer.tokenOfOwnerByIndex(user2, 1)).should.be.bignumber.eq(this.tokenIds[4]);
  });

  it('tokenOfOwnerByIndex: should fail if index is oob', async () => {
    let result = this.assetIntroducer.tokenOfOwnerByIndex(user, 3);
    await expectRevert(result, 'ERC721TokenLib::tokenOfOwnerByIndex: INVALID_INDEX');
    result = this.assetIntroducer.tokenOfOwnerByIndex(user2, 2);
    await expectRevert(result, 'ERC721TokenLib::tokenOfOwnerByIndex: INVALID_INDEX');
  });

  it('getAllTokensOf: should send back proper amounts for legit owners', async () => {
    (await this.assetIntroducer.getAllTokensOf(user)).length.should.be.eq(3);
    (await this.assetIntroducer.getAllTokensOf(user2)).length.should.be.eq(2);
  });

  it('getAllTokensOf: should send back nothing for an invalid owner', async () => {
    (await this.assetIntroducer.getAllTokensOf(guardian)).length.should.be.eq(0);
  });

});