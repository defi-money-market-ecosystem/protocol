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

import "./v1/IDMGYieldFarmingV1Initializable.sol";

contract DMGYieldFarmingProxy is AdminUpgradeabilityProxy {

    /**
     * @param __logic                   The address of the initial implementation.
     * @param __admin                   The address of the proxy administrator.
     * @param __dmgToken                The address of the DMG token.
     * @param __guardian                The address of the guardian of the implementation contract.
     * @param __dmmController           The address of the DMM Controller for the DMM: Ecosystem.
     * @param __dmgGrowthCoefficient    The rate at which DMG is distributed for each point farmed, per second.
     * @param __allowableTokens         The list of initially-farmable tokens.
     * @param __underlyingTokens        The list of tokens that underpin `allowableTokens`, which the DMM: Underlying
     *                                  Token Valuator can decipher.
     * @param __tokenDecimals           The number of decimals each token has.
     * @param __points                  The amount of points each dollar of token/underlying is worth. This acts as a
     *                                  multiplier, using base `DMGYieldFarmingData::ONE_REWARD_POINTS`.
     */
    constructor(
        address __logic,
        address __admin,
        address __dmgToken,
        address __guardian,
        address __dmmController,
        uint __dmgGrowthCoefficient,
        address[] memory __allowableTokens,
        address[] memory __underlyingTokens,
        uint8[] memory __tokenDecimals,
        uint16[] memory __points
    )
    AdminUpgradeabilityProxy(
        __logic,
        __admin,
        abi.encodePacked(
            IDMGYieldFarmingV1Initializable(address(0)).initialize.selector,
            abi.encode(__dmgToken, __guardian, __dmmController, __dmgGrowthCoefficient, __allowableTokens, __underlyingTokens, __tokenDecimals, __points)
        )
    )
    public {}

    function getImplementation() public view returns (address) {
        return _implementation();
    }

    function _willFallback() internal {
        // Don't call super. We want the __admin to be able to call-through to the implementation contract
    }

}