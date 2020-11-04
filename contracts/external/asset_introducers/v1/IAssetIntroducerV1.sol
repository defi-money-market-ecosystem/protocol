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

interface IAssetIntroducerV1 {

    // *************************
    // ***** Events
    // *************************

    event SignatureValidated(address indexed signer, uint nonce);
    event AssetIntroducerBought(uint indexed tokenId, address indexed buyer, address indexed recipient, uint dmgAmount);
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    // *************************
    // ***** Admin Functions
    // *************************

    function createAssetIntroducersForPrimaryMarket(
        string[] calldata countryCode,
        AssetIntroducerData.AssetIntroducerType[] calldata introducerType,
        uint[] calldata dmgPriceAmount
    ) external returns (uint[] memory);

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
    // ***** Misc Functions
    // *************************

    /**
     * @return  The domain separator used in off-chain signatures. See EIP 712 for more:
     *          https://eips.ethereum.org/EIPS/eip-712
     */
    function domainSeparator() external view returns (bytes32);

    /**
     * @return  The address of the DMG token
     */
    function dmg() external view returns (address);

    function underlyingTokenValuator() external view returns (address);

    /**
     * @return  The discount applied to the price of the asset introducer for being an early purchaser. Represented as
     *          a number with 18 decimals, such that 0.1 * 1e18 == 10%
     */
    function getAssetIntroducerDiscount() external view returns (uint);

    /**
     * @return  The price of the asset introducer, represented in USD
     */
    function getAssetIntroducerPriceUsd(
        uint tokenId
    ) external returns (uint);

    /**
     * @return  The price of the asset introducer, represented in DMG. DMG is the needed currency to purchase an asset
     *          introducer NFT.
     */
    function getAssetIntroducerPriceDmg(
        uint tokenId
    ) external returns (uint);

    /**
     * @return  The total amount of DMG locked in the asset introducer reserves
     */
    function getTotalDmgLocked() external view returns (uint);

    /**
     * @return  The amount that this asset introducer can manager, represented in wei format (a number with 18
     *          decimals). Meaning, 10,000.25 * 1e18 == $10,000.25
     */
    function getDollarAmountToManageByTokenId(
        uint tokenId
    ) external view returns (uint);

    /**
     * @return  The amount of DMG that this asset introducer has locked in order to maintain a valid status as an asset
     *          introducer.
     */
    function getDmgLockedByTokenId(
        uint tokenId
    ) external view returns (uint);

    function getAssetIntroducersByCountryCode(
        string calldata countryCode
    ) external view returns (AssetIntroducerData.AssetIntroducer[] memory);

    function getAllAssetIntroducers() external view returns (AssetIntroducerData.AssetIntroducer[] memory);

    function getPrimaryMarketAssetIntroducers() external view returns (AssetIntroducerData.AssetIntroducer[] memory);

    function getSecondaryMarketAssetIntroducers() external view returns (AssetIntroducerData.AssetIntroducer[] memory);

    // *************************
    // ***** User Functions
    // *************************

    /**
     * Buys the slot for the appropriate amount of DMG, by attempting to transfer the DMG from `msg.sender` to this
     * contract
     */
    function buyAssetIntroducerSlot(
        uint tokenId
    ) external returns (bool);

    function nonceOf(
        address user
    ) external view returns (uint);

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

    function getPriorVotes(
        address user,
        uint blockNumber
    ) external view returns (uint128);

    function getCurrentVotes(
        address user
    ) external view returns (uint);

    function getDmgLockedByUser(
        address user
    ) external view returns (uint);

}