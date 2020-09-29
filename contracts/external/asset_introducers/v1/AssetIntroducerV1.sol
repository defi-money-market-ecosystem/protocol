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

import "../impl/ERC721.sol";

import "./IAssetIntroducerV1.sol";

contract AssetIntroducerV1 is ERC721Token, IAssetIntroducerV1 {

    // *************************
    // ***** Admin Functions
    // *************************

    function initialize(
        address owner,
        address guardian
    )
    public
    initializer {
        IOwnableOrGuardian.initialize(owner, guardian);
    }

    function _verifyAndConvertCountryCodeToBytes(
        string memory countryCode
    ) internal pure returns (bytes3) {
        require(
            bytes(countryCode).length == 3,
            "AssetIntroducerV1::_verifyAndConvertCountryCodeToBytes: INVALID_COUNTRY_CODE"
        );
        bytes3 result;
        assembly {
            result := mload(add(countryCode, 3))
        }
        return result;
    }

    function createAssetIntroducerForPrimaryMarket(
        string calldata countryCode,
        AssetIntroducerData.AssetIntroducerType introducerType,
        uint dmgPriceAmount
    )
    external
    onlyOwnerOrGuardian
    returns (uint) {
        bytes3 countryCode = _verifyAndConvertCountryCodeToBytes(countryCode);
        uint nonce = _countryCodeToAssetIntroducerTypeToCountMap[countryCode][uint8(introducerType)];
        uint tokenId = uint(keccak256(abi.encodePacked(countryCode, uint8(introducerType), nonce)));

        _mint(address(this), tokenId);

        return tokenId;
    }


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

    /**
     * Buys the slot for the appropriate amount of DMG, by attempting to transfer the DMG from `msg.sender` to this
     * contract
     */
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

    function getVoteCount(
        address owner
    ) external view returns (uint);

    function getDmgLockedByOwner(
        address owner
    ) external view returns (uint);

    // *************************
    // ***** Misc Functions
    // *************************

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

}