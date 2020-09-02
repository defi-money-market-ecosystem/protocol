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

contract DMGYieldFarmingProxy is AdminUpgradeabilityProxy, IDMGYieldFarmingV1Initializable {

    /**
     * @param logic                 The address of the initial implementation.
     * @param admin                 The address of the proxy administrator.
     * @param dmgToken              The address of the DMG token.
     * @param guardian              The address of the guardian of the implementation contract.
     * @param dmmController         The address of the DMM Controller for the DMM: Ecosystem.
     * @param dmgGrowthCoefficient  The rate at which DMG is distributed for each point farmed, per second.
     * @param allowableTokens       The list of initially-farmable tokens.
     * @param underlyingTokens      The list of tokens that underpin `allowableTokens`, which the DMM: Underlying Token
     *                              Valuator can decipher.
     * @param tokenDecimals         The number of decimals each token has.
     * @param points                The amount of points each dollar of token/underlying is worth. This acts as a
     *                              multiplier, using base `DMGYieldFarmingData::ONE_REWARD_POINTS`.
     */
    constructor(
        address logic,
        address admin,
        address dmgToken,
        address guardian,
        address dmmController,
        uint dmgGrowthCoefficient,
        address[] memory allowableTokens,
        address[] memory underlyingTokens,
        uint8[] memory tokenDecimals,
        uint16[] memory points
    )
    AdminUpgradeabilityProxy(
        logic,
        admin,
        abi.encodePacked(
            this.initialize.selector,
            abi.encode(dmgToken, guardian, dmmController, dmgGrowthCoefficient, allowableTokens, underlyingTokens, tokenDecimals, points)
        )
    )
    public {}

}