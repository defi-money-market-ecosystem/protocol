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

    event AssetIntroducerBought(uint indexed tokenId, address indexed buyer, address indexed recipient, uint dmgAmount);
    event AssetIntroducerActivationChanged(uint indexed tokenId, bool isActivated);
    event AssetIntroducerCreated(uint indexed tokenId, string countryCode, AssetIntroducerData.AssetIntroducerType introducerType, uint serialNumber);
    event AssetIntroducerDiscountChanged(address indexed oldAssetIntroducerDiscount, address indexed newAssetIntroducerDiscount);
    event AssetIntroducerDollarAmountToManageChange(uint indexed tokenId, uint oldDollarAmountToManage, uint newDollarAmountToManage);
    event AssetIntroducerPriceChanged(string indexed countryCode, AssetIntroducerData.AssetIntroducerType indexed introducerType, uint oldPriceUsd, uint newPriceUsd);
    event BaseURIChanged(string newBaseURI);
    event CapitalDeposited(uint indexed tokenId, address indexed token, uint amount);
    event CapitalWithdrawn(uint indexed tokenId, address indexed token, uint amount);
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);
    event InterestPaid(uint indexed tokenId, address indexed token, uint amount);
    event SignatureValidated(address indexed signer, uint nonce);
    event StakingPurchaserChanged(address indexed oldStakingPurchaser, address indexed newStakingPurchaser);

    // *************************
    // ***** Admin Functions
    // *************************

    function createAssetIntroducersForPrimaryMarket(
        string[] calldata countryCode,
        AssetIntroducerData.AssetIntroducerType[] calldata introducerType
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

    function setAssetIntroducerDiscount(
        address assetIntroducerDiscount
    ) external;

    function setAssetIntroducerPrice(
        string calldata countryCode,
        AssetIntroducerData.AssetIntroducerType introducerType,
        uint priceUsd
    ) external;

    function activateAssetIntroducerByTokenId(
        uint tokenId
    ) external;

    function setStakingPurchaser(
        address stakingPurchaser
    ) external;

    // *************************
    // ***** Misc Functions
    // *************************

    /**
     * @return  The timestamp at which this contract was created
     */
    function initTimestamp() external view returns (uint64);

    function stakingPurchaser() external view returns (address);

    function openSeaProxyRegistry() external view returns (address);

    /**
     * @return  The domain separator used in off-chain signatures. See EIP 712 for more:
     *          https://eips.ethereum.org/EIPS/eip-712
     */
    function domainSeparator() external view returns (bytes32);

    /**
     * @return  The address of the DMG token
     */
    function dmg() external view returns (address);

    function dmmController() external view returns (address);

    function underlyingTokenValuator() external view returns (address);

    function assetIntroducerDiscount() external view returns (address);

    /**
     * @return  The discount applied to the price of the asset introducer for being an early purchaser. Represented as
     *          a number with 18 decimals, such that 0.1 * 1e18 == 10%
     */
    function getAssetIntroducerDiscount() external view returns (uint);

    /**
     * @return  The price of the asset introducer, represented in USD
     */
    function getAssetIntroducerPriceUsdByTokenId(
        uint tokenId
    ) external view returns (uint);

    /**
     * @return  The price of the asset introducer, represented in DMG. DMG is the needed currency to purchase an asset
     *          introducer NFT.
     */
    function getAssetIntroducerPriceDmgByTokenId(
        uint tokenId
    ) external view returns (uint);

    function getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(
        string calldata countryCode,
        AssetIntroducerData.AssetIntroducerType introducerType
    )
    external view returns (uint);

    function getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(
        string calldata countryCode,
        AssetIntroducerData.AssetIntroducerType introducerType
    )
    external view returns (uint);

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

    function getAssetIntroducerByTokenId(
        uint tokenId
    ) external view returns (AssetIntroducerData.AssetIntroducer memory);

    function getAssetIntroducersByCountryCode(
        string calldata countryCode
    ) external view returns (AssetIntroducerData.AssetIntroducer[] memory);

    function getAllAssetIntroducers() external view returns (AssetIntroducerData.AssetIntroducer[] memory);

    function getPrimaryMarketAssetIntroducers() external view returns (AssetIntroducerData.AssetIntroducer[] memory);

    function getSecondaryMarketAssetIntroducers() external view returns (AssetIntroducerData.AssetIntroducer[] memory);

    // *************************
    // ***** User Functions
    // *************************

    function getNonceByUser(
        address user
    ) external view returns (uint);

    function getNextAssetIntroducerTokenId(
        string calldata __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType
    ) external view returns (uint);

    /**
     * Buys the slot for the appropriate amount of DMG, by attempting to transfer the DMG from `msg.sender` to this
     * contract
     */
    function buyAssetIntroducerSlot(
        uint tokenId
    ) external returns (bool);

    /**
     * Buys the slot for the appropriate amount of DMG, by attempting to transfer the DMG from `msg.sender` to this
     * contract. The additional discount is added to the existing one
     */
    function buyAssetIntroducerSlotViaStaking(
        uint tokenId,
        uint additionalDiscount
    ) external returns (bool);

    function nonceOf(
        address user
    ) external view returns (uint);

    function buyAssetIntroducerSlotBySig(
        uint tokenId,
        address recipient,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (bool);

    function buyAssetIntroducerSlotBySigWithDmgPermit(
        uint __tokenId,
        address __recipient,
        uint __nonce,
        uint __expiry,
        uint8 __v,
        bytes32 __r,
        bytes32 __s,
        AssetIntroducerData.DmgApprovalStruct calldata dmgApprovalStruct
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

    /**
     * @return  The amount of capital that has been withdrawn by this asset introducer, denominated in USD with 18
     *          decimals
     */
    function getDeployedCapitalUsdByTokenId(
        uint tokenId
    ) external view returns (uint);

    function getWithdrawnAmountByTokenIdAndUnderlyingToken(
        uint tokenId,
        address underlyingToken
    ) external view returns (uint);

    /**
     * @dev Deactivates the specified asset introducer from being able to withdraw funds. Doing so enables it to
     *      be transferred. NOTE: NFTs can only be deactivated once all deployed capital is returned.
     */
    function deactivateAssetIntroducerByTokenId(
        uint tokenId
    ) external;

    function withdrawCapitalByTokenIdAndToken(
        uint tokenId,
        address token,
        uint amount
    ) external;

    function depositCapitalByTokenIdAndToken(
        uint tokenId,
        address token,
        uint amount
    ) external;

    function payInterestByTokenIdAndToken(
        uint tokenId,
        address token,
        uint amount
    ) external;

    // *************************
    // ***** Other Functions
    // *************************

    /**
     * @dev Used by the DMMF to buy its token and initialize it based upon its usage of the protocol prior to the NFT
     *      system having been created. We are passing through the USDC token specifically, because it was drawn down
     *      by 300,000 early in the system's maturity to run a full cycle of the system and do a small allocation to
     *      the bootstrapped asset pool.
     */
    function buyDmmFoundationToken(
        uint tokenId,
        address usdcToken
    ) external returns (bool);

    function isDmmFoundationSetup() external view returns (bool);

}