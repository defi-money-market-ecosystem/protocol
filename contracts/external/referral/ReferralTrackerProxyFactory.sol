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
        return proxyContracts;
    }

    function deployProxy() public onlyOwner returns (address) {
        ReferralTrackerProxy proxy = new ReferralTrackerProxy(weth);

        proxyContracts.push(address(proxy));
        proxy.transferOwnership(owner());

        emit ProxyContractDeployed(address(proxy));

        return address(proxy);
    }

}