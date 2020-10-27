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

    address internal _dmg;

    uint internal _totalDmgLocked;

    bytes32 _domainSeparator;

    uint internal _totalSupply;

    uint[] internal _allTokens;

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
    }

    struct Checkpoint {
        uint64 fromBlock;
        uint128 votes;
    }

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

    modifier requireIsPrimaryMarketNft(uint __tokenId) {
        require(
            !_idToAssetIntroducer[__tokenId].isOnSecondaryMarket,
            "AssetIntroducerData: IS_SECONDARY_MARKET"
        );

        _;
    }

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