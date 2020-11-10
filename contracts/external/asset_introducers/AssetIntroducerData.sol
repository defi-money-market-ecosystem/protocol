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

    uint internal constant LINKED_LIST_GUARD = uint(1);

    string public constant NAME = "AssetIntroducer";

    // *************************
    // ***** V1 State Variables
    // *************************

    /// The timestamp at which this contract was initialized
    uint64 _initTimestamp;

    address internal _dmg;

    address internal _underlyingTokenValuator;

    uint internal _totalDmgLocked;

    bytes32 _domainSeparator;

    uint internal _totalSupply;

    /**
     * @dev The last token ID in the linked list.
     */
    uint internal _lastTokenId;

    /**
     * @dev Mapping of all token IDs. Works as a linked list such that previous key --> next value. The 0th key in the
     *      list is LINKED_LIST_GUARD.
     */
    mapping(uint => uint) internal _allTokens;

    mapping(uint => AssetIntroducer) internal _idToAssetIntroducer;

    /**
     * @dev Mapping from NFT ID to owner address.
     */
    mapping(uint256 => address) internal _idToOwnerMap;

    /**
     * @dev Mapping from NFT ID to approved address.
     */
    mapping(uint256 => address) internal _idToSpenderMap;

    /**
     * @dev Mapping from owner to an operator that can spend all of owner's NFTs.
     */
    mapping(address => mapping(address => bool)) internal _ownerToOperatorToIsApprovedMap;

    /**
     * @dev Mapping for the count of each user's off-chain signed messages. 0-indexed.
     */
    mapping(address => uint) internal _ownerToNonceMap;

    /**
     * @dev  Mapping from owner address to all owned token IDs. Works as a linked list such that previous key --> next
     *       value. The 0th key in the list is LINKED_LIST_GUARD.
     */
    mapping(address => mapping(uint => uint)) internal _ownerToTokenIds;

    /**
    * @dev Mapping from owner address to a count of all owned NFTs.
    */
    mapping(address => uint32) internal _ownerToTokenCount;

    mapping(bytes3 => mapping(uint8 => uint[])) internal _countryCodeToAssetIntroducerTypeToTokenIdsMap;

    /**
     * @dev Mapping from an interface to whether or not it's supported.
     */
    mapping(bytes4 => bool) internal _interfaceIdToIsSupportedMap;

    /**
     * @dev Taken from the DMG token implementation
     */
    mapping(address => mapping(uint64 => Checkpoint)) internal _ownerToCheckpointIndexToCheckpointMap;

    /**
     * @dev Taken from the DMG token implementation
     */
    mapping(address => uint64) internal _ownerToCheckpointCountMap;

    /**
     * @dev A mapping from the country code to asset introducer type to the cost needed to buy one. The cost is
     *      represented in USD (with 18 decimals) and is purchased using DMG, so a conversion is needed using Chainlink.
     */
    mapping(bytes3 => mapping(uint8 => uint96)) internal _countryCodeToAssetIntroducerTypeToPriceUsd;

    // *************************
    // ***** Data Structures
    // *************************

    enum AssetIntroducerType {
        PRINCIPAL, AFFILIATE
    }

    struct AssetIntroducer {
        bytes3 countryCode;
        AssetIntroducerType introducerType;
        /// True if the asset introducer has been purchased yet, false if it hasn't and is thus
        bool isOnSecondaryMarket;
        uint96 dmgLocked;
        /// An override on how much this asset introducer can manager; the default amount for a `countryCode` and
        /// `introducerType` can be retrieved via function call
        uint104 dollarAmountToManage;
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

    // *************************
    // ***** Modifiers
    // *************************

    /// Enforces that an NFT has NOT been sold to a user yet
    modifier requireIsPrimaryMarketNft(uint __tokenId) {
        require(
            !_idToAssetIntroducer[__tokenId].isOnSecondaryMarket,
            "AssetIntroducerData: IS_SECONDARY_MARKET"
        );

        _;
    }

    /// Enforces that an NFT has been sold to a user
    modifier requireIsSecondaryMarketNft(uint __tokenId) {
        require(
            _idToAssetIntroducer[__tokenId].isOnSecondaryMarket,
            "AssetIntroducerData: IS_PRIMARY_MARKET"
        );

        _;
    }

    modifier requireIsValidNft(uint __tokenId) {
        require(
            _idToOwnerMap[__tokenId] != address(0),
            "AssetIntroducerData: INVALID_NFT"
        );

        _;
    }

}