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
import "../../../../node_modules/@openzeppelin/contracts/utils/Address.sol";

import "../../../protocol/interfaces/IDmmController.sol";
import "../../../utils/IERC20WithDecimals.sol";

import "../impl/ERC721TokenLib.sol";

import "../AssetIntroducerData.sol";
import "./AssetIntroducerV1UserLib.sol";
import "./IAssetIntroducerV1.sol";

library AssetIntroducerV1AdminLib {

    using Address for address;
    using AssetIntroducerV1UserLib for *;
    using ERC721TokenLib for AssetIntroducerData.ERC721StateV1;
    using SafeMath for uint;

    // *************************
    // ***** Events
    // *************************

    event AssetIntroducerCreated(uint indexed tokenId, string countryCode, AssetIntroducerData.AssetIntroducerType introducerType, uint serialNumber);
    event AssetIntroducerDiscountChanged(address indexed oldAssetIntroducerDiscount, address indexed newAssetIntroducerDiscount);
    event AssetIntroducerDollarAmountToManageChange(uint indexed tokenId, uint oldDollarAmountToManage, uint newDollarAmountToManage);
    event AssetIntroducerPriceChanged(string indexed countryCode, AssetIntroducerData.AssetIntroducerType indexed introducerType, uint oldPriceUsd, uint newPriceUsd);

    // *************************
    // ***** Functions
    // *************************

    function createAssetIntroducersForPrimaryMarket(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        AssetIntroducerData.ERC721StateV1 storage __erc721State,
        string[] calldata __countryCodes,
        AssetIntroducerData.AssetIntroducerType[] calldata __introducerTypes
    )
    external
    returns (uint[] memory) {
        require(
            __countryCodes.length == __introducerTypes.length,
            "AssetIntroducerV1Lib::createAssetIntroducersForPrimaryMarket: INVALID_LENGTH"
        );

        uint[] memory tokenIds = new uint[](__countryCodes.length);

        uint totalSupply = __erc721State.totalSupply;

        for (uint i = 0; i < __countryCodes.length; i++) {
            bytes3 countryCode = AssetIntroducerV1UserLib._verifyAndConvertCountryCodeToBytes(__countryCodes[i]);
            uint8 introducerType = uint8(__introducerTypes[i]);
            tokenIds[i] = AssetIntroducerV1UserLib._getAssetIntroducerTokenId(__state, countryCode, introducerType);

            require(
                __state.countryCodeToAssetIntroducerTypeToPriceUsd[countryCode][introducerType] > 0,
                "AssetIntroducerV1Lib::createAssetIntroducersForPrimaryMarket: PRICE_NOT_SET"
            );

            uint16 serialNumber = uint16(totalSupply + i + 1);

            __state.idToAssetIntroducer[tokenIds[i]] = AssetIntroducerData.AssetIntroducer({
            countryCode : countryCode,
            introducerType : __introducerTypes[i],
            isOnSecondaryMarket : false,
            isAllowedToWithdrawFunds : false,
            serialNumber : serialNumber, /// serial number is 1-based indexed
            dmgLocked : 0,
            dollarAmountToManage : 0,
            tokenId : tokenIds[i]
            });

            __state.countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(__introducerTypes[i])].push(tokenIds[i]);

            emit AssetIntroducerCreated(tokenIds[i], __countryCodes[i], __introducerTypes[i], serialNumber);

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
            __dollarAmountToManage == uint96(__dollarAmountToManage),
            "AssetIntroducerV1AdminLib::setDollarAmountToManageByTokenId: INVALID_DOLLAR_AMOUNT"
        );

        AssetIntroducerData.AssetIntroducer storage assetIntroducer = __state.idToAssetIntroducer[__tokenId];
        uint oldDollarAmountToManage = assetIntroducer.dollarAmountToManage;
        assetIntroducer.dollarAmountToManage = uint96(__dollarAmountToManage);
        emit AssetIntroducerDollarAmountToManageChange(__tokenId, oldDollarAmountToManage, __dollarAmountToManage);
    }

    function setDollarAmountToManageByCountryCodeAndIntroducerType(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        string calldata __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType,
        uint __dollarAmountToManage
    )
    external {
        require(
            __dollarAmountToManage == uint96(__dollarAmountToManage),
            "AssetIntroducerV1AdminLib::setDollarAmountToManageByTokenId: INVALID_DOLLAR_AMOUNT"
        );

        bytes3 rawCountryCode = AssetIntroducerV1UserLib._verifyAndConvertCountryCodeToBytes(__countryCode);
        uint[] memory tokenIds = __state.countryCodeToAssetIntroducerTypeToTokenIdsMap[rawCountryCode][uint8(__introducerType)];
        for (uint i = 0; i < tokenIds.length; i++) {
            AssetIntroducerData.AssetIntroducer storage assetIntroducer = __state.idToAssetIntroducer[tokenIds[i]];
            uint oldDollarAmountToManage = assetIntroducer.dollarAmountToManage;
            assetIntroducer.dollarAmountToManage = uint96(__dollarAmountToManage);
            emit AssetIntroducerDollarAmountToManageChange(tokenIds[i], oldDollarAmountToManage, __dollarAmountToManage);
        }
    }

    function setAssetIntroducerDiscount(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        address __assetIntroducerDiscount
    )
    public {
        require(
            __assetIntroducerDiscount != address(0) && __assetIntroducerDiscount.isContract(),
            "AssetIntroducerV1AdminLib::setAssetIntroducerDiscount: INVALID_INTRODUCER_DISCOUNT"
        );

        address oldAssetIntroducerDiscount = __state.assetIntroducerDiscount;
        __state.assetIntroducerDiscount = __assetIntroducerDiscount;
        emit AssetIntroducerDiscountChanged(oldAssetIntroducerDiscount, __assetIntroducerDiscount);
    }

    function setAssetIntroducerPrice(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        string calldata __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType,
        uint __priceUsd
    )
    external {
        require(
            __priceUsd == uint96(__priceUsd),
            "AssetIntroducerV1AdminLib::setAssetIntroducerPrice: INVALID_DOLLAR_AMOUNT"
        );

        bytes3 countryCode = AssetIntroducerV1UserLib._verifyAndConvertCountryCodeToBytes(__countryCode);
        uint oldPriceUsd = __state.countryCodeToAssetIntroducerTypeToPriceUsd[countryCode][uint8(__introducerType)];
        __state.countryCodeToAssetIntroducerTypeToPriceUsd[countryCode][uint8(__introducerType)] = uint96(__priceUsd);
        emit AssetIntroducerPriceChanged(__countryCode, __introducerType, oldPriceUsd, __priceUsd);
    }

}