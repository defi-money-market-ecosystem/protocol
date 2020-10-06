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

import "../AssetIntroducerData.sol";

interface IAssetIntroducerV1 {

    // *************************
    // ***** Events
    // *************************

    event AssetIntroducerBought(uint indexed tokenId, address indexed buyer, uint dmgAmount);

    // *************************
    // ***** Admin Functions
    // *************************

    function createAssetIntroducerForPrimaryMarket(
        string calldata countryCode,
        AssetIntroducerData.AssetIntroducerType introducerType,
        uint dmgPriceAmount
    ) external returns (uint);

    function setDollarAmountToManageByTokenId(
        uint tokenId,
        uint dollarAmountToManage
    ) external;

    function setDollarAmountToManageByCountryCodeAndIntroducerType(
        string calldata countryCode,
        AssetIntroducerData.AssetIntroducerType introducerType,
        uint dollarAmountToManage
    ) external;

    // *************************
    // ***** User Functions
    // *************************

    function buyAssetIntroducerSlot(
        uint tokenId
    ) external returns (bool);

    function buyAssetIntroducerSlotBySig(
        uint tokenId,
        address recipient,
        uint amount,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bool);

    function getAssetIntroducerPrice(
        uint tokenId
    ) external returns (uint);

    function getCurrentVotesByUser(
        address user
    ) external view returns (uint);

    function getDmgLockedByUser(
        address user
    ) external view returns (uint);

    function getTotalDmgLocked() external view returns (uint);

    function getDollarAmountToManageByTokenId(
        uint tokenId
    ) external view returns (uint);

    function getDmgLockedByTokenId(
        uint tokenId
    ) external view returns (uint);

    function getAssetIntroducersByCountryCode(
        string calldata countryCode
    ) external view returns (uint[] memory);

    /**
     * @return  The address of the DMG token
     */
    function dmg() external view returns (address);

}