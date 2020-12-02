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

import "../../../node_modules/@openzeppelin/upgrades/contracts/Initializable.sol";

import "../../protocol/interfaces/IOwnableOrGuardian.sol";
import "../../governance/dmg/IDMGToken.sol";

contract AssetIntroducerData is Initializable, IOwnableOrGuardian {

    // *************************
    // ***** Constants
    // *************************

    // *************************
    // ***** V1 State Variables
    // *************************

    /// For preventing reentrancy attacks
    uint64 internal _guardCounter;

    AssetIntroducerStateV1 internal _assetIntroducerStateV1;

    ERC721StateV1 internal _erc721StateV1;

    VoteStateV1 internal _voteStateV1;

    // *************************
    // ***** Data Structures
    // *************************

    enum AssetIntroducerType {
        PRINCIPAL, AFFILIATE
    }

    struct AssetIntroducerStateV1 {
        /// The timestamp at which this contract was initialized
        uint64 initTimestamp;

        /// Total amount of DMG locked in this contract
        uint128 totalDmgLocked;

        /// For calculating the results of off-chain signature requests
        bytes32 domainSeparator;

        /// Address of the DMG token
        address dmg;

        /// Address of the DMM Controller
        address dmmController;

        /// Address of the DMM token valuator, which gets the USD value of a token
        address underlyingTokenValuator;

        /// Address of the implementation for the discount
        address assetIntroducerDiscount;

        /// Mapping from NFT ID to the asset introducer struct.
        mapping(uint => AssetIntroducer) idToAssetIntroducer;

        /// Mapping from country code to asset introducer type to token IDs
        mapping(bytes3 => mapping(uint8 => uint[])) countryCodeToAssetIntroducerTypeToTokenIdsMap;

        /// A mapping from the country code to asset introducer type to the cost needed to buy one. The cost is represented
        /// in USD (with 18 decimals) and is purchased using DMG, so a conversion is needed using Chainlink.
        mapping(bytes3 => mapping(uint8 => uint96)) countryCodeToAssetIntroducerTypeToPriceUsd;

        /// The dollar amount that has actually been deployed by the asset introducer
        mapping(uint => mapping(address => uint)) tokenIdToUnderlyingTokenToWithdrawnAmount;

        /// Mapping for the count of each user's off-chain signed messages. 0-indexed.
        mapping(address => uint) ownerToNonceMap;
    }

    struct ERC721StateV1 {
        /// Total number of NFTs created
        uint64 totalSupply;

        /// The last token ID in the linked list.
        uint lastTokenId;

        /// The base URI for getting NFT information by token ID.
        string baseURI;

        /// Mapping of all token IDs. Works as a linked list such that previous key --> next value. The 0th key in the
        /// list is LINKED_LIST_GUARD.
        mapping(uint => uint) allTokens;

        /// Mapping from NFT ID to owner address.
        mapping(uint256 => address) idToOwnerMap;

        /// Mapping from NFT ID to approved address.
        mapping(uint256 => address) idToSpenderMap;

        /// Mapping from owner to an operator that can spend all of owner's NFTs.
        mapping(address => mapping(address => bool)) ownerToOperatorToIsApprovedMap;

        /// Mapping from owner address to all owned token IDs. Works as a linked list such that previous key --> next value.
        /// The 0th key in the list is LINKED_LIST_GUARD.
        mapping(address => mapping(uint => uint)) ownerToTokenIds;

        /// Mapping from owner address to a count of all owned NFTs.
        mapping(address => uint32) ownerToTokenCount;

        /// Mapping from an interface to whether or not it's supported.
        mapping(bytes4 => bool) interfaceIdToIsSupportedMap;
    }

    /// Used for storing information about voting
    struct VoteStateV1 {
        /// Taken from the DMG token implementation
        mapping(address => mapping(uint64 => Checkpoint)) ownerToCheckpointIndexToCheckpointMap;
        /// Taken from the DMG token implementation
        mapping(address => uint64) ownerToCheckpointCountMap;
    }

    /// Tightly-packed, this data structure is 2 slots; 64 bytes
    struct AssetIntroducer {
        bytes3 countryCode;
        AssetIntroducerType introducerType;
        /// True if the asset introducer has been purchased yet, false if it hasn't and is thus
        bool isOnSecondaryMarket;
        /// True if the asset introducer can withdraw tokens from mToken deposits, false if it cannot yet. This value
        /// must only be changed to `true` via governance vote
        bool isAllowedToWithdrawFunds;
        /// 1-based index at which the asset introducer was created. Used for optics
        uint16 serialNumber;
        uint96 dmgLocked;
        /// How much this asset introducer can manage
        uint96 dollarAmountToManage;
        uint tokenId;
    }

    /// Used for tracking delegation and number of votes each user has at a given block height.
    struct Checkpoint {
        uint64 fromBlock;
        uint128 votes;
    }

    /// Used to prevent the "stack too deep" error and make code more readable
    struct DmgApprovalStruct {
        address spender;
        uint rawAmount;
        uint nonce;
        uint expiry;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct DiscountStruct {
        uint64 initTimestamp;
    }

    // *************************
    // ***** Modifiers
    // *************************

    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;

        _;

        require(
            localCounter == _guardCounter,
            "AssetIntroducerData: REENTRANCY"
        );
    }

    /// Enforces that an NFT has NOT been sold to a user yet
    modifier requireIsPrimaryMarketNft(uint __tokenId) {
        require(
            !_assetIntroducerStateV1.idToAssetIntroducer[__tokenId].isOnSecondaryMarket,
            "AssetIntroducerData: IS_SECONDARY_MARKET"
        );

        _;
    }

    /// Enforces that an NFT has been sold to a user
    modifier requireIsSecondaryMarketNft(uint __tokenId) {
        require(
            _assetIntroducerStateV1.idToAssetIntroducer[__tokenId].isOnSecondaryMarket,
            "AssetIntroducerData: IS_PRIMARY_MARKET"
        );

        _;
    }

    modifier requireIsValidNft(uint __tokenId) {
        require(
            _erc721StateV1.idToOwnerMap[__tokenId] != address(0),
            "AssetIntroducerData: INVALID_NFT"
        );

        _;
    }

    modifier requireIsNftOwner(uint __tokenId) {
        require(
            _erc721StateV1.idToOwnerMap[__tokenId] == msg.sender,
            "AssetIntroducerData: INVALID_NFT_OWNER"
        );

        _;
    }

    modifier requireCanWithdrawFunds(uint __tokenId) {
        require(
            _assetIntroducerStateV1.idToAssetIntroducer[__tokenId].isAllowedToWithdrawFunds,
            "AssetIntroducerData: CANNOT_WITHDRAW_FUNDS"
        );

        _;
    }

}