const {accounts, contract, web3} = require('@openzeppelin/test-environment');
const {expect} = require('chai');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
require('chai').should();
const {
  BN,
  expectEvent,
  expectRevert,
} = require('@openzeppelin/test-helpers');
const {
  _001,
  _10000,
  doDmmControllerBeforeEach,
} = require('../helpers/DmmTokenTestHelpers');

// Use the different accounts, which are unlocked and funded with Ether
const [admin, user] = accounts;

describe('DmmController.TransferOwnership', async () => {

  const ownableError = 'Ownable: caller is not the owner';
  const defaultDmmTokenId = new BN('1');

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;
    await doDmmControllerBeforeEach(this, contract, web3);
  });

  it('should transfer ownership of DMM token to the new controller', async () => {
    await addDaiMarket();

    const oldController = this.controller;
    const oldDmmEtherFactory = this.dmmEtherFactory;
    const oldDmmTokenFactory = this.dmmTokenFactory;
    await doDmmControllerBeforeEach(this, contract, web3);

    expect(oldController.address).should.not.equal(this.controller.address);

    await oldController.transferOwnershipToNewController(this.controller.address, {from: admin});

    expect(await oldDmmEtherFactory.owner()).equal(this.controller.address);
    expect(await oldDmmTokenFactory.owner()).equal(this.controller.address);

    const DmmToken = contract.fromArtifact('DmmToken');
    const dmmToken = await DmmToken.at(await oldController.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId));
    expect(await dmmToken.owner()).equal(this.controller.address);
  });

  it('should not transfer ownership of DMM token to new controller if owner does not match', async () => {
    await addDaiMarket();

    const oldController = this.controller;
    await doDmmControllerBeforeEach(this, contract, web3);

    expect(oldController.address).should.not.equal(this.controller.address);

    await expectRevert(
      oldController.transferOwnershipToNewController(this.controller.address, {from: user}),
      ownableError,
    );
  });

  it('should not transfer ownership of DMM token to new controller if new controller is not a contract', async () => {
    await addDaiMarket();
    const oldController = this.controller;

    await expectRevert(
      oldController.transferOwnershipToNewController(user, {from: admin}),
      'NEW_CONTROLLER_IS_NOT_CONTRACT',
    );
  });

  it('should add pre-existing market to new controller', async () => {
    await addDaiMarket();

    const oldController = this.controller;
    await doDmmControllerBeforeEach(this, contract, web3);

    expect(oldController.address).should.not.equal(this.controller.address);

    await oldController.transferOwnershipToNewController(this.controller.address, {from: admin});

    const DmmToken = contract.fromArtifact('DmmToken');
    const dmmToken = await DmmToken.at(await oldController.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId));

    const receipt = await this.controller.addMarketFromExistingDmmToken(dmmToken.address, this.dai.address, {from: admin});
    expectEvent(
      receipt,
      'MarketAdded',
      {dmmTokenId: defaultDmmTokenId, dmmToken: dmmToken.address, underlyingToken: this.dai.address}
    );
  });

  it('should not add pre-existing market to new controller when market already exists', async () => {
    await addDaiMarket();

    const oldController = this.controller;
    await doDmmControllerBeforeEach(this, contract, web3);

    expect(oldController.address).should.not.equal(this.controller.address);

    await oldController.transferOwnershipToNewController(this.controller.address, {from: admin});

    const DmmToken = contract.fromArtifact('DmmToken');
    const dmmToken = await DmmToken.at(await oldController.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId));

    await addDaiMarket();

    await expectRevert(
      this.controller.addMarketFromExistingDmmToken(dmmToken.address, this.dai.address, {from: admin}),
      'TOKEN_ALREADY_EXISTS'
    );
  });

  it('should not add pre-existing market to new controller when market is not owned by controller', async () => {
    await addDaiMarket();

    const oldController = this.controller;
    await doDmmControllerBeforeEach(this, contract, web3);

    expect(oldController.address).should.not.equal(this.controller.address);

    await oldController.transferOwnershipToNewController(this.controller.address, {from: admin});

    const DmmToken = contract.fromArtifact('DmmToken');
    const dmmToken = await DmmToken.at(await oldController.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId));

    await addDaiMarket();

    await expectRevert(
      this.controller.addMarketFromExistingDmmToken(dmmToken.address, this.dai.address, {from: admin}),
      'TOKEN_ALREADY_EXISTS'
    );
  });

  it('should not add pre-existing market to new controller when market is not a contract', async () => {
    await addDaiMarket();

    const oldController = this.controller;
    await doDmmControllerBeforeEach(this, contract, web3);

    expect(oldController.address).should.not.equal(this.controller.address);

    await oldController.transferOwnershipToNewController(this.controller.address, {from: admin});

    await expectRevert(
      this.controller.addMarketFromExistingDmmToken(user, this.dai.address, {from: admin}),
      'DMM_TOKEN_IS_NOT_CONTRACT'
    );
  });

  it('should not add pre-existing market to new controller when underlying is not a contract', async () => {
    await addDaiMarket();

    const oldController = this.controller;
    await doDmmControllerBeforeEach(this, contract, web3);

    expect(oldController.address).should.not.equal(this.controller.address);

    await oldController.transferOwnershipToNewController(this.controller.address, {from: admin});

    const DmmToken = contract.fromArtifact('DmmToken');
    const dmmToken = await DmmToken.at(await oldController.dmmTokenIdToDmmTokenAddressMap(defaultDmmTokenId));

    await expectRevert(
      this.controller.addMarketFromExistingDmmToken(dmmToken.address, user, {from: admin}),
      'UNDERLYING_TOKEN_IS_NOT_CONTRACT'
    );
  });

  /**********************
   * Utility Functions
   */

  const addDaiMarket = async () => {
    const receipt = await this.controller.addMarket(
      this.dai.address,
      "mDAI",
      "DMM: DAI",
      18,
      _001(),
      _001(),
      _10000(),
      {from: admin}
    );

    expectEvent(
      receipt,
      'MarketAdded',
      {dmmTokenId: defaultDmmTokenId, underlyingToken: this.dai.address}
    );
  };

});