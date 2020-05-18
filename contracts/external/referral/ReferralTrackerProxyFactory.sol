pragma solidity ^0.5.0;

import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";

import "./ReferralTrackerProxy.sol";

contract ReferralTrackerProxyFactory is Ownable {

    address public weth;
    address[] public proxyContracts;

    event ProxyContractDeployed(address indexed proxyAddress);

    constructor(address _weth) public {
        weth = _weth;
    }

    function getProxyContracts() public view returns (address[] memory) {
        return getProxyContractsWithIndices(0, proxyContracts.length);
    }

    /**
     * @param startIndex inclusive start point for `proxyContracts` mapping to array
     * @param endIndex exclusive end point for `proxyContracts` mapping to array
     */
    function getProxyContractsWithIndices(uint startIndex, uint endIndex) public view returns (address[] memory) {
        require(endIndex >= startIndex, "INVALID_INDICES");
        require(endIndex <= proxyContracts.length, "INVALID_END_INDEX");

        address[] memory retVal = new address[](endIndex - startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            retVal[i - startIndex] = proxyContracts[i];
        }
        return retVal;
    }

    function deployProxy() public onlyOwner returns (address) {
        ReferralTrackerProxy proxy = new ReferralTrackerProxy(weth);

        proxyContracts.push(address(proxy));
        proxy.transferOwnership(owner());

        emit ProxyContractDeployed(address(proxy));

        return address(proxy);
    }

}