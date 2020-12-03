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

import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../../../protocol/interfaces/IDmmController.sol";
import "../../../utils/IERC20WithDecimals.sol";

import "../impl/ERC721TokenLib.sol";

import "../interfaces/IAssetIntroducerDiscount.sol";

import "../AssetIntroducerData.sol";
import "./IAssetIntroducerV1.sol";

library AssetIntroducerV1UserLib {

    using ERC721TokenLib for AssetIntroducerData.ERC721StateV1;
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    // *************************
    // ***** Constants
    // *************************

    uint internal constant ONE_ETH = 1e18;

    // *************************
    // ***** Events
    // *************************

    event AssetIntroducerActivationChanged(uint indexed tokenId, bool isActivated);
    event AssetIntroducerBought(uint indexed tokenId, address indexed buyer, address indexed recipient, uint dmgAmount);
    event CapitalDeposited(uint indexed tokenId, address indexed token, uint amount);
    event CapitalWithdrawn(uint indexed tokenId, address indexed token, uint amount);
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);
    event InterestPaid(uint indexed tokenId, address indexed token, uint amount);
    event SignatureValidated(address indexed signer, uint nonce);

    // *************************
    // ***** Functions
    // *************************

    function buyAssetIntroducer(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId,
        address __recipient,
        address __buyer,
        AssetIntroducerData.ERC721StateV1 storage __erc721State,
        AssetIntroducerData.VoteStateV1 storage __voteState,
        uint __additionalDiscount
    ) public {
        uint dmgPurchasePrice = getAssetIntroducerPriceDmgByTokenId(__state, __tokenId, __additionalDiscount);
        IERC20(__state.dmg).safeTransferFrom(__buyer, address(this), dmgPurchasePrice);
        __state.totalDmgLocked = uint128(uint(__state.totalDmgLocked).add(dmgPurchasePrice));

        AssetIntroducerData.AssetIntroducer storage introducer = __state.idToAssetIntroducer[__tokenId];
        introducer.isOnSecondaryMarket = true;
        introducer.dmgLocked = uint96(dmgPurchasePrice);

        // Initialize the DMG voting balance to this contract. The call to _transfer moves it to __recipient then.
        AssetIntroducerVotingLib.moveDelegates(__voteState, address(0), address(this), uint128(dmgPurchasePrice));

        ERC721TokenLib._transfer(__erc721State, __voteState, __recipient, __tokenId, introducer);

        emit AssetIntroducerBought(__tokenId, __buyer, __recipient, dmgPurchasePrice);
    }

    function validateOfflineSignature(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        bytes32 __structHash,
        uint __nonce,
        uint __expiry,
        uint8 __v,
        bytes32 __r,
        bytes32 __s
    )
    public
    returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", __state.domainSeparator, __structHash));
        signer = ecrecover(digest, __v, __r, __s);

        require(
            signer != address(0),
            "AssetIntroducerV1UserLib::_validateOfflineSignature: INVALID_SIGNATURE"
        );
        require(
            __nonce == __state.ownerToNonceMap[signer]++,
            "AssetIntroducerV1UserLib::_validateOfflineSignature: INVALID_NONCE"
        );
        require(
            block.timestamp <= __expiry,
            "AssetIntroducerV1UserLib::_validateOfflineSignature: EXPIRED"
        );

        emit SignatureValidated(signer, __nonce);
    }

    function getDeployedCapitalUsdByTokenId(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId
    ) public view returns (uint) {
        IDmmController dmmController = IDmmController(__state.dmmController);
        IUnderlyingTokenValuator underlyingTokenValuator = IUnderlyingTokenValuator(__state.underlyingTokenValuator);
        uint[] memory tokenIds = dmmController.getDmmTokenIds();

        uint totalDeployedCapital = 0;
        for (uint i = 0; i < tokenIds.length; i++) {
            address token = dmmController.getUnderlyingTokenForDmm(dmmController.getDmmTokenAddressByDmmTokenId(tokenIds[i]));
            uint rawDeployedAmount = __state.tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][token];
            rawDeployedAmount = _standardizeTokenAmountForUsdDecimals(
                rawDeployedAmount,
                IERC20WithDecimals(token).decimals()
            );

            totalDeployedCapital = totalDeployedCapital.add(underlyingTokenValuator.getTokenValue(token, rawDeployedAmount));
        }

        return totalDeployedCapital;
    }

    function getDmgLockedByUser(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        AssetIntroducerData.ERC721StateV1 storage __erc721State,
        address __user
    ) public view returns (uint) {
        uint[] memory tokenIds = ERC721TokenLib.getAllTokensOf(__erc721State, __user);
        uint dmgLocked = 0;
        for (uint i = 0; i < tokenIds.length; i++) {
            dmgLocked = dmgLocked.add(__state.idToAssetIntroducer[tokenIds[i]].dmgLocked);
        }
        return dmgLocked;
    }

    function getAssetIntroducerDiscount(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state
    ) public view returns (uint) {
        AssetIntroducerData.DiscountStruct memory discountStruct = AssetIntroducerData.DiscountStruct({
        initTimestamp : __state.initTimestamp
        });
        return IAssetIntroducerDiscount(__state.assetIntroducerDiscount).getAssetIntroducerDiscount(discountStruct);
    }

    function getAssetIntroducerPriceUsdByTokenId(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId,
        uint __additionalDiscount
    )
    public view returns (uint) {
        AssetIntroducerData.AssetIntroducer memory assetIntroducer = __state.idToAssetIntroducer[__tokenId];
        return getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(
            __state,
            string(abi.encodePacked(assetIntroducer.countryCode)),
            assetIntroducer.introducerType,
            __additionalDiscount
        );
    }

    function getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        string memory __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType,
        uint __additionalDiscount
    )
    public view returns (uint) {
        bytes3 countryCode = _verifyAndConvertCountryCodeToBytes(__countryCode);
        uint priceUsd = __state.countryCodeToAssetIntroducerTypeToPriceUsd[countryCode][uint8(__introducerType)];
        uint discount = getAssetIntroducerDiscount(__state).add(__additionalDiscount);
        require(
            discount < ONE_ETH,
            "AssetIntroducerV1UserLib::getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType: INVALID_DISCOUNT"
        );
        return priceUsd.mul(ONE_ETH.sub(discount)).div(ONE_ETH);
    }

    function getAssetIntroducerPriceDmgByTokenId(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId,
        uint __additionalDiscount
    )
    public view returns (uint) {
        uint dmgPriceUsd = IUnderlyingTokenValuator(__state.underlyingTokenValuator).getTokenValue(__state.dmg, 1e18);
        return getAssetIntroducerPriceUsdByTokenId(__state, __tokenId, __additionalDiscount).mul(1e18).div(dmgPriceUsd);
    }

    function getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        string memory __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType,
        uint __additionalDiscount
    )
    public view returns (uint) {
        uint dmgPriceUsd = IUnderlyingTokenValuator(__state.underlyingTokenValuator).getTokenValue(__state.dmg, 1e18);
        return getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(__state, __countryCode, __introducerType, __additionalDiscount).mul(1e18).div(dmgPriceUsd);
    }

    function getAssetIntroducersByCountryCode(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        string calldata __countryCode
    ) external view returns (AssetIntroducerData.AssetIntroducer[] memory) {
        bytes3 countryCode = _verifyAndConvertCountryCodeToBytes(__countryCode);
        uint[] memory affiliates = __state.countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(AssetIntroducerData.AssetIntroducerType.AFFILIATE)];
        uint[] memory principals = __state.countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(AssetIntroducerData.AssetIntroducerType.PRINCIPAL)];

        AssetIntroducerData.AssetIntroducer[] memory assetIntroducers = new AssetIntroducerData.AssetIntroducer[](affiliates.length + principals.length);
        for (uint i = 0; i < affiliates.length + principals.length; i++) {
            if (i < affiliates.length) {
                assetIntroducers[i] = __state.idToAssetIntroducer[affiliates[i]];
            } else {
                assetIntroducers[i] = __state.idToAssetIntroducer[principals[i - affiliates.length]];
            }
        }
        return assetIntroducers;
    }

    function getAllAssetIntroducers(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        AssetIntroducerData.ERC721StateV1 storage __erc721State
    ) public view returns (AssetIntroducerData.AssetIntroducer[] memory) {
        uint nextTokenId = ERC721TokenLib.linkedListGuard();
        AssetIntroducerData.AssetIntroducer[] memory assetIntroducers = new AssetIntroducerData.AssetIntroducer[](__erc721State.totalSupply);
        for (uint i = 0; i < assetIntroducers.length; i++) {
            assetIntroducers[i] = __state.idToAssetIntroducer[__erc721State.allTokens[nextTokenId]];
            nextTokenId = __erc721State.allTokens[nextTokenId];
        }
        return assetIntroducers;
    }

    function getPrimaryMarketAssetIntroducers(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        AssetIntroducerData.ERC721StateV1 storage __erc721State
    ) external view returns (AssetIntroducerData.AssetIntroducer[] memory) {
        AssetIntroducerData.AssetIntroducer[] memory allAssetIntroducers = getAllAssetIntroducers(__state, __erc721State);
        uint primaryMarketCount = 0;
        for (uint i = 0; i < allAssetIntroducers.length; i++) {
            if (!allAssetIntroducers[i].isOnSecondaryMarket) {
                primaryMarketCount += 1;
            }
        }

        AssetIntroducerData.AssetIntroducer[] memory primaryMarketAssetIntroducers = new AssetIntroducerData.AssetIntroducer[](primaryMarketCount);
        uint j = 0;
        for (uint i = 0; i < allAssetIntroducers.length; i++) {
            if (!allAssetIntroducers[i].isOnSecondaryMarket) {
                primaryMarketAssetIntroducers[j++] = allAssetIntroducers[i];
            }
        }
        return primaryMarketAssetIntroducers;
    }

    function getSecondaryMarketAssetIntroducers(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        AssetIntroducerData.ERC721StateV1 storage __erc721State
    ) external view returns (AssetIntroducerData.AssetIntroducer[] memory) {
        AssetIntroducerData.AssetIntroducer[] memory allAssetIntroducers = getAllAssetIntroducers(__state, __erc721State);
        uint secondaryMarketCount = 0;
        for (uint i = 0; i < allAssetIntroducers.length; i++) {
            if (allAssetIntroducers[i].isOnSecondaryMarket) {
                secondaryMarketCount += 1;
            }
        }

        AssetIntroducerData.AssetIntroducer[] memory secondaryMarketAssetIntroducers = new AssetIntroducerData.AssetIntroducer[](secondaryMarketCount);
        uint j = 0;
        for (uint i = 0; i < allAssetIntroducers.length; i++) {
            if (allAssetIntroducers[i].isOnSecondaryMarket) {
                secondaryMarketAssetIntroducers[j++] = allAssetIntroducers[i];
            }
        }
        return secondaryMarketAssetIntroducers;
    }

    function deactivateAssetIntroducerByTokenId(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId
    )
    public {
        require(
            getDeployedCapitalUsdByTokenId(__state, __tokenId) == 0,
            "AssetIntroducerV1UserLib::deactivateAssetIntroducerByTokenId: MUST_DEPOSIT_REMAINING_CAPITAL"
        );
        require(
            __state.idToAssetIntroducer[__tokenId].isAllowedToWithdrawFunds,
            "AssetIntroducerV1UserLib::deactivateAssetIntroducerByTokenId: ALREADY_DEACTIVATED"
        );
        __state.idToAssetIntroducer[__tokenId].isAllowedToWithdrawFunds = false;
        emit AssetIntroducerActivationChanged(__tokenId, false);
    }

    function withdrawCapitalByTokenIdAndToken(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId,
        address __token,
        uint __amount
    )
    public {
        uint standardizedAmount = _standardizeTokenAmountForUsdDecimals(
            __amount,
            IERC20WithDecimals(__token).decimals()
        );
        uint deployedCapital = getDeployedCapitalUsdByTokenId(__state, __tokenId);
        uint usdAmountToWithdraw = IUnderlyingTokenValuator(__state.underlyingTokenValuator).getTokenValue(__token, standardizedAmount);

        require(
            deployedCapital.add(usdAmountToWithdraw) <= __state.idToAssetIntroducer[__tokenId].dollarAmountToManage,
            "AssetIntroducerV1UserLib::withdrawCapitalByTokenId: AUM_OVERFLOW"
        );

        __state.tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token] = __state.tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token].add(__amount);

        IDmmController dmmController = IDmmController(__state.dmmController);
        uint dmmTokenId = dmmController.getTokenIdFromDmmTokenAddress(dmmController.getDmmTokenForUnderlying(__token));
        dmmController.adminWithdrawFunds(dmmTokenId, __amount);
        IERC20(__token).safeTransfer(msg.sender, __amount);
        emit CapitalWithdrawn(__tokenId, __token, __amount);
    }

    function depositCapitalByTokenIdAndToken(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId,
        address __token,
        uint __amount
    )
    public {
        require(
            __state.tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token] >= __amount,
            "AssetIntroducerV1UserLib::depositCapitalByTokenId: AUM_UNDERFLOW"
        );
        __state.tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token] = __state.tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token].sub(__amount);

        IERC20(__token).safeTransferFrom(msg.sender, address(this), __amount);

        IDmmController dmmController = IDmmController(__state.dmmController);
        uint dmmTokenId = dmmController.getTokenIdFromDmmTokenAddress(dmmController.getDmmTokenForUnderlying(__token));

        IERC20(__token).safeApprove(address(dmmController), __amount);
        dmmController.adminDepositFunds(dmmTokenId, __amount);

        emit CapitalDeposited(__tokenId, __token, __amount);
    }

    function payInterestByTokenIdAndToken(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        uint __tokenId,
        address __token,
        uint __amount
    )
    public {
        IERC20(__token).safeTransferFrom(msg.sender, address(this), __amount);

        IDmmController dmmController = IDmmController(__state.dmmController);
        uint dmmTokenId = dmmController.getTokenIdFromDmmTokenAddress(dmmController.getDmmTokenForUnderlying(__token));

        IERC20(__token).safeApprove(address(dmmController), __amount);
        dmmController.adminDepositFunds(dmmTokenId, __amount);

        emit InterestPaid(__tokenId, __token, __amount);
    }

    // ******************************
    // ***** Internal Functions
    // ******************************

    function _getAssetIntroducerTokenId(
        AssetIntroducerData.AssetIntroducerStateV1 storage __state,
        bytes3 __countryCode,
        uint8 __introducerType
    ) internal view returns (uint) {
        uint nonce = __state.countryCodeToAssetIntroducerTypeToTokenIdsMap[__countryCode][__introducerType].length;
        return uint(keccak256(abi.encodePacked(__countryCode, __introducerType, nonce)));
    }

    function _verifyAndConvertCountryCodeToBytes(
        string memory __countryCode
    ) internal pure returns (bytes3) {
        require(
            bytes(__countryCode).length == 3,
            "AssetIntroducerV1UserLib::_verifyAndConvertCountryCodeToBytes: INVALID_COUNTRY_CODE"
        );
        bytes32 result;
        assembly {
            result := mload(add(__countryCode, 32))
        }
        return bytes3(result);
    }

    function _standardizeTokenAmountForUsdDecimals(
        uint __amount,
        uint8 __decimals
    ) internal pure returns (uint) {
        if (__decimals > 18) {
            return __amount.div(10 ** uint(__decimals - 18));
        } else if (__decimals < 18) {
            return __amount.mul(10 ** uint(18 - __decimals));
        } else {
            return __amount;
        }
    }

}