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
import "./IAssetIntroducerV1.sol";

library AssetIntroducerV1Lib {

    using SafeMath for uint;
    using ERC721TokenLib for AssetIntroducerData.ERC721StateV1;

    // *************************
    // ***** Events
    // *************************

    event SignatureValidated(address indexed signer, uint nonce);
    event BaseURIChanged(string newBaseURI);

    // *************************
    // ***** Functions
    // *************************

    function setBaseURI(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        string calldata __baseURI
    ) external {
        __state.baseURI = __baseURI;
        emit BaseURIChanged(__baseURI);
    }

    function tokenURI(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId
    ) public view returns (string memory) {
        bytes32 tokenIdBytes;
        while (__tokenId > 0) {
            tokenIdBytes = bytes32(uint(tokenIdBytes) / (2 ** 8));
            tokenIdBytes |= bytes32(((__tokenId % 10) + 48) * 2 ** (8 * 31));
            __tokenId /= 10;
        }
        return string(abi.encodePacked(__state.baseURI, tokenIdBytes));
    }

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
            bytes3 countryCode = _verifyAndConvertCountryCodeToBytes(__countryCodes[i]);
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

    function getDeployedCapitalByTokenId(
        IAssetIntroducerV1 state,
        uint __tokenId
    ) public view returns (uint) {
        IDmmController dmmController = IDmmController(state.dmmController());
        IUnderlyingTokenValuator underlyingTokenValuator = IUnderlyingTokenValuator(state.underlyingTokenValuator());
        uint[] memory tokenIds = dmmController.getDmmTokenIds();

        uint totalDeployedCapital = 0;
        for (uint i = 0; i < tokenIds.length; i++) {
            address token = dmmController.getUnderlyingTokenForDmm(dmmController.getDmmTokenAddressByDmmTokenId(tokenIds[i]));
            uint rawDeployedAmount = state.getTotalWithdrawnUnderlyingByTokenId(__tokenId, token);
            rawDeployedAmount = standardizeTokenAmountForUsdDecimals(
                rawDeployedAmount,
                IERC20WithDecimals(token).decimals()
            );

            totalDeployedCapital = totalDeployedCapital.add(underlyingTokenValuator.getTokenValue(token, rawDeployedAmount));
        }

        return totalDeployedCapital;
    }

    function validateOfflineSignature(
        IAssetIntroducerV1 state,
        bytes32 __structHash,
        uint __nonce,
        uint __expiry,
        uint8 __v,
        bytes32 __r,
        bytes32 __s
    )
    public
    returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", state.domainSeparator(), __structHash));
        signer = ecrecover(digest, __v, __r, __s);

        require(
            signer != address(0),
            "AssetIntroducerV1Lib::_validateOfflineSignature: INVALID_SIGNATURE"
        );
        require(
            __nonce == state.getNonceByUser(signer),
            "AssetIntroducerV1Lib::_validateOfflineSignature: INVALID_NONCE"
        );
        require(
            block.timestamp <= __expiry,
            "AssetIntroducerV1Lib::_validateOfflineSignature: EXPIRED"
        );

        emit SignatureValidated(signer, __nonce);
    }

    function _verifyAndConvertCountryCodeToBytes(
        string memory __countryCode
    ) internal pure returns (bytes3) {
        require(
            bytes(__countryCode).length == 3,
            "AssetIntroducerV1Lib::_verifyAndConvertCountryCodeToBytes: INVALID_COUNTRY_CODE"
        );
        bytes3 result;
        assembly {
            result := mload(add(__countryCode, 3))
        }
        return result;
    }

    function standardizeTokenAmountForUsdDecimals(
        uint __amount,
        uint8 __decimals
    ) public pure returns (uint) {
        if (__decimals > 18) {
            return __amount.div(10 ** uint(__decimals - 18));
        } else if (__decimals < 18) {
            return __amount.mul(10 ** uint(18 - __decimals));
        } else {
            return __amount;
        }
    }

}