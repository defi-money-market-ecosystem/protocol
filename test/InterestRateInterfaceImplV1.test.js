const {accounts, contract} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/configure');
const {expect} = require('chai');
require('chai').should();
const {BN} = require('@openzeppelin/test-helpers');


// Use the different accounts, which are unlocked and funded with Ether
const [admin, deployer, user] = accounts;

// Create a contract object from a compilation artifact
const InterestRateInterfaceImplV1 = contract.fromArtifact('InterestRateInterfaceImplV1');

const expectedInterestRate = new BN('62500000000000000');

describe('InterestRateInterfaceImplV1', () => {

  beforeEach(async () => {
    this.contract = await InterestRateInterfaceImplV1.new();
  });

  it('should get the interest rate', async () => {
    // Store a value - recall that only the owner account can do this!
    const tokenId1 = new BN(1);
    (await this.contract.getInterestRate(tokenId1, new BN(0), new BN(0))).should.be.bignumber.equal(expectedInterestRate);

    const tokenId2 = new BN(2);
    (await this.contract.getInterestRate(tokenId2, new BN(0), new BN(0))).should.be.bignumber.equal(expectedInterestRate);
  });
});
