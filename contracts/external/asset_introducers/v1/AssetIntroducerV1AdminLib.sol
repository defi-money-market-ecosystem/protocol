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

import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../../../protocol/interfaces/IDmmController.sol";
import "../../../utils/IERC20WithDecimals.sol";

import "../impl/ERC721TokenLib.sol";

import "../AssetIntroducerData.sol";
import "./AssetIntroducerV1UserLib.sol";
import "./IAssetIntroducerV1.sol";

library AssetIntroducerV1AdminLib {

    using SafeMath for uint;
    using ERC721TokenLib for AssetIntroducerData.ERC721StateV1;
    using AssetIntroducerV1UserLib for *;

    // *************************
    // ***** Events
    // *************************

    event SignatureValidated(address indexed signer, uint nonce);

    // *************************
    // ***** Functions
    // *************************

    function createAssetIntroducersForPrimaryMarket(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        AssetIntroducerData.ERC721StateV1 storage __erc721State,
        string[] calldata __countryCodes,
        AssetIntroducerData.AssetIntroducerType[] calldata __introducerTypes,
        uint[] calldata __dmgPriceAmounts
    )
    external
    returns (uint[] memory) {
        require(
            __countryCodes.length == __introducerTypes.length,
            "AssetIntroducerV1Lib::createAssetIntroducersForPrimaryMarket: INVALID_LENGTH"
        );
        require(
            __countryCodes.length == __dmgPriceAmounts.length,
            "AssetIntroducerV1Lib::createAssetIntroducersForPrimaryMarket: INVALID_LENGTH"
        );

        uint[] memory tokenIds = new uint[](__countryCodes.length);

        for (uint i = 0; i < __countryCodes.length; i++) {
            bytes3 countryCode = AssetIntroducerV1UserLib._verifyAndConvertCountryCodeToBytes(__countryCodes[i]);
            uint nonce = __state.countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(__introducerTypes[i])].length;
            tokenIds[i] = uint(keccak256(abi.encodePacked(countryCode, uint8(__introducerTypes[i]), nonce)));

            __state.idToAssetIntroducer[tokenIds[i]] = AssetIntroducerData.AssetIntroducer({
            countryCode : countryCode,
            introducerType : __introducerTypes[i],
            isOnSecondaryMarket : false,
            isAllowedToWithdrawFunds : false,
            dmgLocked : 0,
            dollarAmountToManage : 0,
            tokenId : tokenIds[i]
            });

            __state.countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(__introducerTypes[i])].push(tokenIds[i]);

            __erc721State.mint(address(this), tokenIds[i]);
        }

        return tokenIds;
    }

    function setDollarAmountToManageByTokenId(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId,
        uint __dollarAmountToManage
    )
    external {
        require(
            __dollarAmountToManage == uint104(__dollarAmountToManage),
            "AssetIntroducerV1::setDollarAmountToManageByTokenId: INVALID_DOLLAR_AMOUNT"
        );

        __state.idToAssetIntroducer[__tokenId].dollarAmountToManage = uint104(__dollarAmountToManage);
    }

    function setDollarAmountToManageByCountryCodeAndIntroducerType(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        string calldata __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType,
        uint __dollarAmountToManage
    )
    external {
        require(
            __dollarAmountToManage == uint104(__dollarAmountToManage),
            "AssetIntroducerV1::setDollarAmountToManageByTokenId: INVALID_DOLLAR_AMOUNT"
        );

        bytes3 rawCountryCode = AssetIntroducerV1UserLib._verifyAndConvertCountryCodeToBytes(__countryCode);
        uint[] memory tokenIds = __state.countryCodeToAssetIntroducerTypeToTokenIdsMap[rawCountryCode][uint8(__introducerType)];
        for (uint i = 0; i < tokenIds.length; i++) {
            __state.idToAssetIntroducer[tokenIds[i]].dollarAmountToManage = uint104(__dollarAmountToManage);
        }
    }

}