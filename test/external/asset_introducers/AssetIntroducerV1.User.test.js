const {accounts, contract, web3, provider} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {expectRevert, expectEvent, BN, constants, time} = require('@openzeppelin/test-helpers');

const {snapshotChain, resetChain, _1, signMessage} = require('../../helpers/DmmTokenTestHelpers');
const {
  doAssetIntroductionV1BeforeEach,
  createNFTs,
  PRICE_USA_PRINCIPAL,
  PRICE_USA_AFFILIATE,
  PRICE_CHN_PRINCIPAL,
  PRICE_CHN_AFFILIATE,
  PRICE_IND_PRINCIPAL,
  PRICE_IND_AFFILIATE,
  AFFILIATE,
  PRINCIPAL,
} = require('../../helpers/AssetIntroductionHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, guardian, user, user2, owner, other] = accounts;

describe('AssetIntroducerV1.User', () => {
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

  it('buyAssetIntroducerSlot: should work for user with enough funds', async () => {
    const result = this.purchaseResults[user][0];
    expectEvent(
      result,
      'AssetIntroducerBought',
      {buyer: user, recipient: user},
    );
  });

  it('buyAssetIntroducerSlotViaStaking: should not work because it is not setup', async () => {
    const result = this.assetIntroducer.buyAssetIntroducerSlotViaStaking(this.tokenIds[5], '0');
    await expectRevert(
      result,
      'AssetIntroducerData: STAKING_PURCHASER_NOT_SETUP',
    );
  });

  it('buyAssetIntroducerSlotBySig: should work for user with enough funds', async () => {
    const balanceOfBefore = await this.assetIntroducer.balanceOf(this.wallet.address);

    const typeHash = await this.assetIntroducer.BUY_ASSET_INTRODUCER_TYPE_HASH();
    const tokenId = this.tokenIds[this.tokenIds.length - 1];
    const nonce = await this.assetIntroducer.nonceOf(this.wallet.address);
    const expiry = (await time.latest()).add(new BN('10'));

    const signature = await encodeHashAndSignForBuyingAssetIntroducer(typeHash, tokenId, nonce, expiry);

    const result = await this.assetIntroducer.buyAssetIntroducerSlotBySig(
      tokenId,
      this.wallet.address,
      nonce,
      expiry,
      signature.v,
      signature.r,
      signature.s,
    );

    await validatePostBuyingState(tokenId, nonce, expiry, result, balanceOfBefore);
  });

  it('buyAssetIntroducerSlotBySigWithDmgPermit: should work for user with enough funds', async () => {
    const balanceOfBefore = await this.assetIntroducer.balanceOf(this.wallet.address);

    const buyAssetIntroducerTypeHash = await this.assetIntroducer.BUY_ASSET_INTRODUCER_TYPE_HASH();
    const tokenId = this.tokenIds[this.tokenIds.length - 1];
    const nonce = (await this.assetIntroducer.nonceOf(this.wallet.address)).toString();
    const expiry = (await time.latest()).add(new BN('10')).toString();

    const signature = await encodeHashAndSignForBuyingAssetIntroducer(buyAssetIntroducerTypeHash, tokenId, nonce, expiry);

    const approveTypeHash = await this.dmgToken.APPROVE_TYPE_HASH();
    const approvalAmount = constants.MAX_UINT256.toString();
    const dmgPermitSignature = await encodeHashAndSignForDmgPermit(approveTypeHash, this.wallet.address, approvalAmount, nonce, expiry);

    const result = await this.assetIntroducer.buyAssetIntroducerSlotBySigWithDmgPermit(
      tokenId,
      this.wallet.address,
      nonce,
      expiry,
      signature.v,
      signature.r,
      signature.s,
      {spender: this.wallet.address, rawAmount: approvalAmount, nonce, expiry, ...dmgPermitSignature},
    );

    await validatePostBuyingState(tokenId, nonce, expiry, result, balanceOfBefore);
  });

  it('getDmgLockedByUser: should work for all users', async () => {
    const lockedAmountUser1 = this.defaultBalance.sub((await this.dmgToken.balanceOf(user)));
    (await this.assetIntroducer.getDmgLockedByUser(user)).should.be.bignumber.eq(lockedAmountUser1);

    const lockedAmountUser2 = this.defaultBalance.sub((await this.dmgToken.balanceOf(user2)));
    (await this.assetIntroducer.getDmgLockedByUser(user2)).should.be.bignumber.eq(lockedAmountUser2);

    (await this.assetIntroducer.getDmgLockedByUser(other)).should.be.bignumber.eq(new BN('0'));
  });

  it('getAssetIntroducerDiscount: should work assuming 18 month duration', async () => {
    const expectedDiscount = await getExpectedDiscount();
    (await this.assetIntroducer.getAssetIntroducerDiscount()).should.be.bignumber.eq(expectedDiscount);
  });

  it('getAssetIntroducerPriceUsdByTokenId: should work with discount', async () => {
    let expectedPrice = await getExpectedPriceUsdWithDiscount(new BN(PRICE_USA_AFFILIATE));
    let tokenId = this.tokenIds[0];
    (await this.assetIntroducer.getAssetIntroducerPriceUsdByTokenId(tokenId)).should.be.bignumber.eq(expectedPrice);

    expectedPrice = await getExpectedPriceUsdWithDiscount(new BN(PRICE_USA_PRINCIPAL));
    tokenId = this.tokenIds[1];
    (await this.assetIntroducer.getAssetIntroducerPriceUsdByTokenId(tokenId)).should.be.bignumber.eq(expectedPrice);
  });

  it('getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType: should work with discount', async () => {
    let expectedPrice = await getExpectedPriceUsdWithDiscount(new BN(PRICE_USA_AFFILIATE));
    let countryCode = 'USA';
    let introducerType = AFFILIATE;
    (await this.assetIntroducer.getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(countryCode, introducerType)).should.be.bignumber.eq(expectedPrice);

    expectedPrice = await getExpectedPriceUsdWithDiscount(new BN(PRICE_USA_PRINCIPAL));
    countryCode = 'USA';
    introducerType = PRINCIPAL;
    (await this.assetIntroducer.getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(countryCode, introducerType)).should.be.bignumber.eq(expectedPrice);

    expectedPrice = await getExpectedPriceUsdWithDiscount(new BN(PRICE_CHN_AFFILIATE));
    countryCode = 'CHN';
    introducerType = AFFILIATE;
    (await this.assetIntroducer.getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(countryCode, introducerType)).should.be.bignumber.eq(expectedPrice);

    expectedPrice = await getExpectedPriceUsdWithDiscount(new BN(PRICE_CHN_PRINCIPAL));
    countryCode = 'CHN';
    introducerType = PRINCIPAL;
    (await this.assetIntroducer.getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(countryCode, introducerType)).should.be.bignumber.eq(expectedPrice);
  });

  it('getAssetIntroducerPriceDmgByTokenId: should work with discount', async () => {
    let expectedPrice = await getExpectedPriceDmgWithDiscount(new BN(PRICE_USA_AFFILIATE));
    let tokenId = this.tokenIds[0];
    (await this.assetIntroducer.getAssetIntroducerPriceDmgByTokenId(tokenId)).should.be.bignumber.eq(expectedPrice);

    expectedPrice = await getExpectedPriceDmgWithDiscount(new BN(PRICE_USA_PRINCIPAL));
    tokenId = this.tokenIds[1];
    (await this.assetIntroducer.getAssetIntroducerPriceDmgByTokenId(tokenId)).should.be.bignumber.eq(expectedPrice);
  });

  it('getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType: should work with discount', async () => {
    let expectedPrice = await getExpectedPriceDmgWithDiscount(new BN(PRICE_USA_AFFILIATE));
    let countryCode = 'USA';
    let introducerType = AFFILIATE;
    (await this.assetIntroducer.getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(countryCode, introducerType)).should.be.bignumber.eq(expectedPrice);

    expectedPrice = await getExpectedPriceDmgWithDiscount(new BN(PRICE_USA_PRINCIPAL));
    countryCode = 'USA';
    introducerType = PRINCIPAL;
    (await this.assetIntroducer.getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(countryCode, introducerType)).should.be.bignumber.eq(expectedPrice);

    expectedPrice = await getExpectedPriceDmgWithDiscount(new BN(PRICE_CHN_AFFILIATE));
    countryCode = 'CHN';
    introducerType = AFFILIATE;
    (await this.assetIntroducer.getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(countryCode, introducerType)).should.be.bignumber.eq(expectedPrice);

    expectedPrice = await getExpectedPriceDmgWithDiscount(new BN(PRICE_CHN_PRINCIPAL));
    countryCode = 'CHN';
    introducerType = PRINCIPAL;
    (await this.assetIntroducer.getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(countryCode, introducerType)).should.be.bignumber.eq(expectedPrice);
  });

  it('getAssetIntroducersByCountryCode: should work with discount', async () => {
    // ***** NOTE ***** //
    // The implementation of #getAssetIntroducersByCountryCode gets the affiliates first, then the principals

    let countryCode = 'USA';
    let assetIntroducers = await this.assetIntroducer.getAssetIntroducersByCountryCode(countryCode);
    (assetIntroducers.length).should.be.eq(2);
    (assetIntroducers[0].tokenId).should.be.bignumber.eq(this.tokenIds[0]); // tokenIds[0] is the affiliate
    (assetIntroducers[1].tokenId).should.be.bignumber.eq(this.tokenIds[1]); // tokenIds[1] is the principal

    countryCode = 'CHN';
    assetIntroducers = await this.assetIntroducer.getAssetIntroducersByCountryCode(countryCode);
    (assetIntroducers.length).should.be.eq(2);
    (assetIntroducers[0].tokenId).should.be.bignumber.eq(this.tokenIds[2]); // tokenIds[2] is the affiliate
    (assetIntroducers[1].tokenId).should.be.bignumber.eq(this.tokenIds[3]); // tokenIds[3] is the principal
  });

  it('getAllAssetIntroducers: should work', async () => {
    const assetIntroducers = (await this.assetIntroducer.getAllAssetIntroducers());
    (assetIntroducers.length).should.be.eq(this.tokenIds.length);
    assetIntroducers.forEach((assetIntroducer) => {
      if (!this.tokenIds.includes(assetIntroducer.tokenId)) {
        throw 'Could not find a token ID in tokenIds';
      }
    });
    const assetIntroducerTokenIds = assetIntroducers.map(assetIntroducer => assetIntroducer.tokenId);
    this.tokenIds.forEach((tokenId) => {
      if (!assetIntroducerTokenIds.includes(tokenId)) {
        throw 'Could not find a token ID in assetIntroducerTokenIds';
      }
    });
  });

  it('getPrimaryMarketAssetIntroducers: should work', async () => {
    const assetIntroducers = await this.assetIntroducer.getPrimaryMarketAssetIntroducers();
    (assetIntroducers.length).should.be.eq(2);
    assetIntroducers.forEach((assetIntroducer) => {
      if (!this.tokenIds.includes(assetIntroducer.tokenId)) {
        throw 'Could not find a token ID in tokenIds';
      }
    });
    const assetIntroducerTokenIds = assetIntroducers.map(assetIntroducer => assetIntroducer.tokenId);
    (this.tokenIds.slice(this.tokenIds.length - 1)).forEach((tokenId) => {
      if (!assetIntroducerTokenIds.includes(tokenId)) {
        throw 'Could not find a token ID in assetIntroducerTokenIds';
      }
    });
  });

  it('getSecondaryMarketAssetIntroducers: should work', async () => {
    const assetIntroducers = await this.assetIntroducer.getSecondaryMarketAssetIntroducers();
    (assetIntroducers.length).should.be.eq(5);
    assetIntroducers.forEach((assetIntroducer) => {
      if (!this.tokenIds.includes(assetIntroducer.tokenId)) {
        throw 'Could not find a token ID in tokenIds';
      }
    });
    const assetIntroducerTokenIds = assetIntroducers.map(assetIntroducer => assetIntroducer.tokenId);
    (this.tokenIds.slice(0, this.tokenIds.length - 2)).forEach((tokenId) => {
      if (!assetIntroducerTokenIds.includes(tokenId)) {
        throw 'Could not find a token ID in assetIntroducerTokenIds';
      }
    });
  });

  it('getDeployedCapitalUsdByTokenId: should work', async () => {
    const tokenId = this.tokenIds[0];
    const aumAmount = '1000000000000000000000000'; // $1,000,000
    await this.assetIntroducer.activateAssetIntroducerByTokenId(tokenId, {from: owner});
    await this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, aumAmount, {from: owner});

    const token = this.underlyingToken.address;
    const amount = '1000000000000000000000'; // $1,000
    await this.assetIntroducer.withdrawCapitalByTokenIdAndToken(tokenId, token, amount, {from: user});

    (await this.assetIntroducer.getDeployedCapitalUsdByTokenId(this.tokenIds[0])).should.be.bignumber.eq(amount);
    (await this.assetIntroducer.getDeployedCapitalUsdByTokenId(this.tokenIds[1])).should.be.bignumber.eq(new BN('0'));
    (await this.assetIntroducer.getDeployedCapitalUsdByTokenId(this.tokenIds[2])).should.be.bignumber.eq(new BN('0'));
  });

  it('deactivateAssetIntroducerByTokenId: should work', async () => {
    const tokenId = this.tokenIds[0];
    await this.assetIntroducer.activateAssetIntroducerByTokenId(tokenId, {from: owner});

    const result = await this.assetIntroducer.deactivateAssetIntroducerByTokenId(tokenId, {from: user});
    expectEvent(
      result,
      'AssetIntroducerActivationChanged',
      {tokenId: tokenId, isActivated: false}
    );
  });

  it('deactivateAssetIntroducerByTokenId: should not work if already deactivated', async () => {
    const tokenId = this.tokenIds[0];
    const result = this.assetIntroducer.deactivateAssetIntroducerByTokenId(tokenId, {from: user});
    await expectRevert(
      result,
      'AssetIntroducerV1UserLib::deactivateAssetIntroducerByTokenId: ALREADY_DEACTIVATED'
    );
  });

  it('deactivateAssetIntroducerByTokenId: should not work if capital is already deployed', async () => {
    const tokenId = this.tokenIds[0];
    const aumAmount = '1000000000000000000000000'; // $1,000,000
    await this.assetIntroducer.activateAssetIntroducerByTokenId(tokenId, {from: owner});
    await this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, aumAmount, {from: owner});

    const token = this.underlyingToken.address;
    const amount = '1000000000000000000000'; // $1,000
    await this.assetIntroducer.withdrawCapitalByTokenIdAndToken(tokenId, token, amount, {from: user});

    const result = this.assetIntroducer.deactivateAssetIntroducerByTokenId(tokenId, {from: user});
    await expectRevert(
      result,
      'AssetIntroducerV1UserLib::deactivateAssetIntroducerByTokenId: MUST_DEPOSIT_REMAINING_CAPITAL'
    );
  });

  it('withdrawCapitalByTokenIdAndToken: should work if token is activated', async () => {
    const tokenId = this.tokenIds[0];
    const aumAmount = '1000000000000000000000000'; // $1,000,000
    await this.assetIntroducer.activateAssetIntroducerByTokenId(tokenId, {from: owner});
    await this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, aumAmount, {from: owner});

    const token = this.underlyingToken.address;
    const amount = '1000000000000000000000'; // $1,000
    const result = await this.assetIntroducer.withdrawCapitalByTokenIdAndToken(tokenId, token, amount, {from: user});
    expectEvent(
      result,
      'CapitalWithdrawn',
      {tokenId: tokenId, token: token, amount: amount},
    );

    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.eq(amount);
  });

  it('withdrawCapitalByTokenIdAndToken: should not work if token is deactivated', async () => {
    const tokenId = this.tokenIds[0];
    const aumAmount = '1000000000000000000000000'; // $1,000,000
    await this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, aumAmount, {from: owner});

    const token = this.underlyingToken.address;
    const amount = '1000000000000000000000'; // $1,000
    const result = this.assetIntroducer.withdrawCapitalByTokenIdAndToken(tokenId, token, amount, {from: user});
    await expectRevert(
      result,
      'AssetIntroducerData: NFT_NOT_ACTIVATED',
    );
  });

  it('withdrawCapitalByTokenIdAndToken: should not work if token user withdraws more than allowed AUM', async () => {
    const tokenId = this.tokenIds[0];
    const aumAmount = '1000000000000000000000000'; // $1,000,000
    await this.assetIntroducer.activateAssetIntroducerByTokenId(tokenId, {from: owner});
    await this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, aumAmount, {from: owner});

    const token = this.underlyingToken.address;
    const amount = '2000000000000000000000000'; // $2,000
    const result = this.assetIntroducer.withdrawCapitalByTokenIdAndToken(tokenId, token, amount, {from: user});
    await expectRevert(
      result,
      'AssetIntroducerV1UserLib::withdrawCapitalByTokenId: AUM_OVERFLOW',
    );
  });

  it('depositCapitalByTokenIdAndToken: should work if token is activated', async () => {
    const tokenId = this.tokenIds[0];
    const aumAmount = '1000000000000000000000000'; // $1,000,000
    await this.assetIntroducer.activateAssetIntroducerByTokenId(tokenId, {from: owner});
    await this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, aumAmount, {from: owner});

    const token = this.underlyingToken.address;
    const amount = '1000000000000000000000'; // $1,000
    await this.assetIntroducer.withdrawCapitalByTokenIdAndToken(tokenId, token, amount, {from: user});
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.eq(amount);

    await this.underlyingToken.approve(this.assetIntroducer.address, constants.MAX_UINT256, {from: user});

    const result = await this.assetIntroducer.depositCapitalByTokenIdAndToken(tokenId, token, amount, {from: user});
    expectEvent(
      result,
      'CapitalDeposited',
      {tokenId: tokenId, token: token, amount: amount},
    );

    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.eq(new BN('0'));
  });

  it('depositCapitalByTokenIdAndToken: should not work if token was not withdrawn beforehand', async () => {
    const tokenId = this.tokenIds[0];
    const aumAmount = '1000000000000000000000000'; // $1,000,000
    await this.assetIntroducer.activateAssetIntroducerByTokenId(tokenId, {from: owner});
    await this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, aumAmount, {from: owner});

    const token = this.underlyingToken.address;
    const amount = '1000000000000000000000'; // $1,000
    const result = this.assetIntroducer.depositCapitalByTokenIdAndToken(tokenId, token, amount, {from: user});
    await expectRevert(
      result,
      'AssetIntroducerV1UserLib::depositCapitalByTokenId: AUM_UNDERFLOW',
    );
  });

  it('payInterestByTokenIdAndToken: should work if token is activated', async () => {
    const tokenId = this.tokenIds[0];
    const aumAmount = '1000000000000000000000000'; // $1,000,000
    await this.assetIntroducer.activateAssetIntroducerByTokenId(tokenId, {from: owner});
    await this.assetIntroducer.setDollarAmountToManageByTokenId(tokenId, aumAmount, {from: owner});

    const token = this.underlyingToken.address;
    let amount = '1000000000000000000000'; // $1,000
    await this.assetIntroducer.withdrawCapitalByTokenIdAndToken(tokenId, token, amount, {from: user});
    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.eq(amount);

    await this.underlyingToken.approve(this.assetIntroducer.address, constants.MAX_UINT256, {from: user});

    const originalAmount = amount;
    amount = '62500000000000000000'; // $62.50
    const result = await this.assetIntroducer.payInterestByTokenIdAndToken(tokenId, token, amount, {from: user});
    expectEvent(
      result,
      'InterestPaid',
      {tokenId: tokenId, token: token, amount: amount},
    );

    (await this.underlyingToken.balanceOf(user)).should.be.bignumber.eq(new BN(originalAmount).sub(new BN(amount)));
  });

  it('buyDmmFoundationToken: should work if not done yet', async () => {
    let tokenId = this.tokenIds[this.tokenIds.length - 2];
    const underlyingToken = this.underlyingToken.address;
    await this.dmgToken.setBalance(guardian, new BN('10000000000000000000000000'));
    await this.dmgToken.approve(this.assetIntroducer.address, constants.MAX_UINT256, {from: guardian});

    let result = this.assetIntroducer.buyDmmFoundationToken(tokenId, this.underlyingToken.address, {from: other});
    await expectRevert(result, 'OwnableOrGuardian: UNAUTHORIZED_OWNER_OR_GUARDIAN');

    result = await this.assetIntroducer.buyDmmFoundationToken(tokenId, this.underlyingToken.address, {from: guardian});
    expectEvent(
      result,
      'AssetIntroducerBought',
      {buyer: guardian, recipient: guardian},
    );
    const withdrawnAmount = new BN('300000000000000000000000');
    expectEvent(
      result,
      'CapitalWithdrawn',
      {tokenId: tokenId, token: underlyingToken, amount: withdrawnAmount},
    );

    (await this.assetIntroducer.getTotalWithdrawnUnderlyingByTokenId(tokenId, underlyingToken)).should.be.bignumber.eq(withdrawnAmount);
    (await this.assetIntroducer.isDmmFoundationSetup()).should.be.eq(true);

    tokenId = this.tokenIds[this.tokenIds.length - 1];
    result = this.assetIntroducer.buyDmmFoundationToken(tokenId, underlyingToken, {from: guardian});
    await expectRevert(
      result,
      'AssetIntroducerV1::buyDmmFoundationToken: ALREADY_SETUP'
    );
  });

  // *************************
  // ***** Private Functions
  // *************************

  const getExpectedPriceUsdWithDiscount = async (price) => {
    const expectedDiscount = await getExpectedDiscount();
    const ONE_ETH = new BN('1000000000000000000');
    return price.mul(ONE_ETH.sub(expectedDiscount)).div(ONE_ETH);
  }

  const getExpectedPriceDmgWithDiscount = async (price) => {
    const expectedDiscount = await getExpectedDiscount();
    const ONE_ETH = new BN('1000000000000000000');

    const ONE_USD = new BN('100000000');
    const DMG_USD_PRICE = new BN(this.dmgUsdPrice);

    return price.mul(ONE_ETH.sub(expectedDiscount)).div(ONE_ETH).mul(ONE_USD).div(DMG_USD_PRICE);
  }

  const getExpectedDiscount = async () => {
    const discountDuration = new BN('46656000'); // 18 months
    const elapsedTime = (await time.latest()).sub(await this.assetIntroducer.initTimestamp());
    return new BN('900000000000000000').mul(discountDuration.sub(elapsedTime)).div(discountDuration);
  }

  const validatePostBuyingState = async (tokenId, nonce, expiry, result, balanceOfBefore) => {
    expectEvent(
      result,
      'AssetIntroducerBought',
      {tokenId: tokenId, buyer: this.wallet.address, recipient: this.wallet.address},
    );

    expectEvent(
      result,
      'SignatureValidated',
      {signer: this.wallet.address, nonce: nonce},
    );

    (await this.assetIntroducer.nonceOf(this.wallet.address)).should.be.bignumber.eq(new BN('1'));

    const balanceOfAfter = await this.assetIntroducer.balanceOf(this.wallet.address);
    (balanceOfBefore.add(new BN('1'))).should.be.bignumber.eq(balanceOfAfter);
  }

  const encodeHashAndSignForBuyingAssetIntroducer = async (typeHash, tokenId, nonce, expiry) => {
    const domainSeparator = await this.assetIntroducer.domainSeparator();
    const messageHash = web3.utils.sha3(
      web3.eth.abi.encodeParameters(
        [
          'bytes32',
          'uint',
          'uint',
          'uint',
        ],
        [
          typeHash,
          tokenId.toString(),
          nonce.toString(),
          expiry.toString(),
        ]
      )
    );
    const digest = web3.utils.soliditySha3('\x19\x01', domainSeparator, messageHash);
    return signMessage(this, digest);
  };

  const encodeHashAndSignForDmgPermit = async (typeHash, spenderAddress, amount, nonce, expiry) => {
    const domainSeparator = await this.dmgToken.domainSeparator();
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
          spenderAddress,
          amount.toString(),
          nonce.toString(),
          expiry.toString(),
        ]
      )
    );
    const digest = web3.utils.soliditySha3('\x19\x01', domainSeparator, messageHash);
    return signMessage(this, digest);
  };

});