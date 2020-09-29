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

contract AssetIntroducerData is Initializable, IOwnableOrGuardian {

    // *************************
    // ***** V1 State Variables
    // *************************

    address internal _dmg;
    address internal _wDmg;

    /**
     * @dev A mapping from NFT ID to the address that owns it.
     */
    mapping(uint256 => address) internal _idToOwner;

    /**
     * @dev Mapping from NFT ID to approved address.
     */
    mapping(uint256 => address) internal _idToApproval;

    /**
    * @dev Mapping from owner address to count of his tokens.
    */
    mapping(address => uint256) internal _ownerToTokenCount;

    /**
     * @dev Mapping from owner address to mapping of operator addresses.
     */
    mapping(address => mapping(address => bool)) internal _ownerToOperators;

    mapping(bytes4 => mapping(uint8 => uint16)) internal _countryCodeToAssetIntroducerTypeToCountMap;

    /**
     * @dev Mapping from an interface to whether or not it's supported.
     */
    mapping(bytes4 => bool) internal _supportedInterfaces;

    // *************************
    // ***** Data Structures
    // *************************

    enum AssetIntroducerType {
        PRINCIPAL, AFFILIATE
    }

    struct AssetIntroducer {
        bytes4 countryCode;
        AssetIntroducerType introducerType;
        /// True if the asset introducer has been purchased yet, false if it hasn't and is thus
        bool isOnSecondaryMarket;
        uint96 dmgLocked;
        /// An override on how much this asset introducer can manager; the default amount for a `countryCode` and
        /// `introducerType` can be retrieved via function call
        uint104 dollarAmountToManage;
    }

}