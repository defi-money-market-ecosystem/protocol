/*
 * Copyright 2020 DMM Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


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