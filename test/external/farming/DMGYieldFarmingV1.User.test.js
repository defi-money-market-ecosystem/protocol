const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectRevert, expectEvent, send, balance} = require('@openzeppelin/test-helpers');

const {doYieldFarmingBeforeEach, setApproval, _001, _1, _10000, _0, signMessage} = require('../../helpers/DmmTokenTestHelpers');


// Use the different accounts, which are unlocked and funded with Ether
const [admin, user, otherUser] = accounts;

// Create a contract object from a compilation artifact
const DMGYieldFarming = contract.fromArtifact('DMGYieldFarming');

describe('DMGYieldFarming', () => {
  let farming = null;

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;

    this.wallet = web3.eth.accounts.create();
    const password = 'password';
    await web3.eth.personal.importRawKey(this.wallet.privateKey, password);
    await web3.eth.personal.unlockAccount(this.wallet.address, password, 600);

    await doYieldFarmingBeforeEach(this, contract, web3);
  });

  it('should get', async () => {

  });

});