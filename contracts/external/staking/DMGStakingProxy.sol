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

import "../../../node_modules/@openzeppelin/upgrades/contracts/upgradeability/AdminUpgradeabilityProxy.sol";

import "./v1/IDMGStakingV1Initializable.sol";

contract DMGStakingProxy is AdminUpgradeabilityProxy {

    /**
     * @param __logic   The address of the initial implementation.
     * @param __admin   The address of the proxy administrator.
     */
    constructor(
        address __logic,
        address __admin
    )
    AdminUpgradeabilityProxy(
        __logic,
        __admin,
        abi.encodePacked(
            IDMGStakingV1Initializable(address(0)).initialize.selector,
            abi.encode("")
        )
    )
    public {}

    function getImplementation() external view returns (address) {
        return _implementation();
    }

    function _willFallback() internal {
        // Don't call super. We want the admin to be able to call-through to the implementation contract
    }

}