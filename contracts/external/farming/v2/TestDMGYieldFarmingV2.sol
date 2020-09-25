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

import "./DMGYieldFarmingV2.sol";

/**
 * @dev Includes an initializer with the V2 specification
 */
contract TestDMGYieldFarmingV2 is DMGYieldFarmingV2 {

    ////////////////////
    // Initializer Functions
    // ////////////////////

    function initialize(
        address __dmgToken,
        address __guardian,
        address __dmmController,
        uint __dmgGrowthCoefficient,
        address[] memory __allowableTokens,
        address[] memory __underlyingTokens,
        uint8[] memory __tokenDecimals,
        uint16[] memory __points
    )
    initializer
    public {
        DMGYieldFarmingData.initialize(__guardian);

        require(
            __allowableTokens.length == __points.length,
            "DMGYieldFarming::initialize: INVALID_LENGTH"
        );
        require(
            __points.length == __underlyingTokens.length,
            "DMGYieldFarming::initialize: INVALID_LENGTH"
        );
        require(
            __underlyingTokens.length == __tokenDecimals.length,
            "DMGYieldFarming::initialize: INVALID_LENGTH"
        );

        _dmgToken = __dmgToken;
        _guardian = __guardian;
        _dmmController = __dmmController;

        _verifyDmgGrowthCoefficient(__dmgGrowthCoefficient);
        _dmgGrowthCoefficient = __dmgGrowthCoefficient;
        _seasonIndex = 1;
        // gas savings by starting it at 1.
        _isFarmActive = false;

        for (uint i = 0; i < __allowableTokens.length; i++) {
            require(
                __allowableTokens[i] != address(0),
                "DMGYieldFarming::initialize: INVALID_UNDERLYING"
            );
            require(
                __underlyingTokens[i] != address(0),
                "DMGYieldFarming::initialize: INVALID_UNDERLYING"
            );

            _supportedFarmTokens.push(__allowableTokens[i]);
            _tokenToIndexPlusOneMap[__allowableTokens[i]] = i + 1;
            _tokenToUnderlyingTokenMap[__allowableTokens[i]] = __underlyingTokens[i];
            _tokenToDecimalsMap[__allowableTokens[i]] = __tokenDecimals[i];

            _verifyPoints(__points[i]);
            _tokenToRewardPointMap[__allowableTokens[i]] = __points[i];
        }
    }

}