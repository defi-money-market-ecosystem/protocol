const {accounts, contract} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/configure');
require('chai').should();
const {BN} = require('@openzeppelin/test-helpers');

// Create a contract object from a compilation artifact
const InterestRateImplV1 = contract.fromArtifact('InterestRateImplV1');

const expectedInterestRate = new BN('62500000000000000');

describe('InterestRateImplV1', () => {

  beforeEach(async () => {
    this.contract = await InterestRateImplV1.new();
  });

  it('should get the interest rate', async () => {
    // Store a value - recall that only the owner account can do this!
    const tokenId1 = new BN(1);
    (await this.contract.getInterestRate(tokenId1, new BN(0), new BN(0))).should.be.bignumber.equal(expectedInterestRate);

    const tokenId2 = new BN(2);
    (await this.contract.getInterestRate(tokenId2, new BN(0), new BN(0))).should.be.bignumber.equal(expectedInterestRate);
  });
});
