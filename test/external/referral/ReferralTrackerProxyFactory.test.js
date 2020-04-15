const {accounts, contract, web3} = require('@openzeppelin/test-environment');
require('@openzeppelin/test-helpers/src/config/web3').getWeb3 = () => web3;
const {expect} = require('chai');
require('chai').should();
const {BN, constants, expectRevert, expectEvent} = require('@openzeppelin/test-helpers');

const {doDmmTokenBeforeEach, setApproval, _10000, _0} = require('../../helpers/DmmTokenTestHelpers');


// Use the different accounts, which are unlocked and funded with Ether
const [admin, user] = accounts;

// Create a contract object from a compilation artifact
const ReferralTrackerProxyFactory = contract.fromArtifact('ReferralTrackerProxyFactory');
const ReferralTrackerProxy = contract.fromArtifact('ReferralTrackerProxy');

describe('ReferralTrackerProxy', () => {
  let proxyFactory = null;

  beforeEach(async () => {
    this.admin = admin;
    this.user = user;

    proxyFactory = await ReferralTrackerProxyFactory.new({from: admin});
  });

  it('should deploy proxy from owner', async () => {
    const receipt = await proxyFactory.deployProxy({from: admin});
    expectEvent(
      receipt,
      'ProxyContractDeployed',
    );

    const addresses = await proxyFactory.getProxyContracts();
    expect(addresses.length).equal(1);

    const proxy = await ReferralTrackerProxy.at(addresses[0]);
    expect((await proxy.owner())).equal(admin);
  });

  it('should not deploy proxy from non-owner', async () => {
    await expectRevert(
      proxyFactory.deployProxy({from: user}),
      'Ownable: caller is not the owner',
    );

    const addresses = await proxyFactory.getProxyContracts();
    expect(addresses.length).equal(0);
  });
});
