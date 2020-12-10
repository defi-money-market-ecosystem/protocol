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
pragma experimental ABIEncoderV2;

import "../AssetIntroducerData.sol";
import "../AssetIntroducerStakingData.sol";

interface IAssetIntroducerStakingV1 {

    // *************************
    // ***** Events
    // *************************

    event UserBeginStaking(address indexed user, uint indexed tokenId, address dmmToken, uint amount, uint unlockTimestamp);
    event UserEndStaking(address indexed user, uint indexed tokenId, address dmmToken, uint amount);
    event IncentiveDmgUsed(uint indexed tokenId, address indexed buyer, uint amount);

    // *************************
    // ***** Misc Functions
    // *************************

    function assetIntroducerProxy() external view returns (address);

    function dmg() external view returns (address);

    function dmgIncentivesPool() external view returns (address);

    function isReady() external view returns (bool);

    /// The total discount received by the user by staking their mTokens.
    function getTotalDiscountByStakingDuration(
        AssetIntroducerStakingData.StakingDuration duration
    ) external view returns (uint);

    /// Returns the DMG price and the additional discount to be forwarded to the asset introducer proxy
    function getAssetIntroducerPriceDmgByTokenIdAndStakingDuration(
        uint tokenId,
        AssetIntroducerStakingData.StakingDuration duration
    ) external view returns (uint, uint);

    // *************************
    // ***** User Functions
    // *************************

    function buyAssetIntroducerSlot(
        uint tokenId,
        uint dmmTokenId,
        AssetIntroducerStakingData.StakingDuration duration
    ) external returns (bool);

    function withdrawStake() external;

    function getUserStakesByAddress(
        address user
    ) external view returns (AssetIntroducerStakingData.UserStake[] memory);

    function getActiveUserStakesByAddress(
        address user
    ) external view returns (AssetIntroducerStakingData.UserStake[] memory);

    function balanceOf(
        address user,
        address mToken
    ) external view returns (uint);

    function getStakeAmountByTokenIdAndDmmTokenId(
        uint tokenId,
        uint dmmTokenId
    ) external view returns (uint);

    function getStakeAmountByCountryCodeAndIntroducerTypeAndDmmTokenId(
        string calldata countryCode,
        AssetIntroducerData.AssetIntroducerType introducerType,
        uint dmmTokenId
    ) external view returns (uint);

    function mapDurationEnumToSeconds(
        AssetIntroducerStakingData.StakingDuration duration
    ) external pure returns (uint64);

}