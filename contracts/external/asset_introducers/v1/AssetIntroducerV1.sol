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

import "../../../utils/EvmUtil.sol";

import "../../../governance/dmg/SafeBitMath.sol";

import "../../../protocol/interfaces/IUnderlyingTokenValuator.sol";
import "../../../protocol/interfaces/IDmmController.sol";

import "../../../utils/IERC20WithDecimals.sol";

import "../impl/ERC721Token.sol";
import "../impl/AssetIntroducerVotingLib.sol";

import "./IAssetIntroducerV1.sol";
import "./AssetIntroducerV1UserLib.sol";

contract AssetIntroducerV1 is ERC721Token, IAssetIntroducerV1 {

    using AssetIntroducerV1Lib for *;
    using AssetIntroducerVotingLib for *;
    using SafeERC20 for IERC20;
    using SafeBitMath for uint128;
    using SafeMath for uint;

    // *************************
    // ***** Constants
    // *************************

    uint public constant ONE_ETH = 1e18;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPE_HASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the purchase struct used by the contract
    bytes32 public constant BUY_ASSET_INTRODUCER_TYPE_HASH = keccak256("BuyAssetIntroducer(uint256 tokenId,uint256 nonce,uint256 expiry)");

    // *************************
    // ***** Admin Functions
    // *************************

    function initialize(
        address __owner,
        address __guardian,
        address __dmg,
        address __dmmController,
        address __underlyingTokenValuator,
        string calldata __baseURI
    )
    external
    initializer {
        ERC721Token.initialize();
        IOwnableOrGuardian.initialize(__owner, __guardian);

        _assetIntroducerStateV1.dmg = __dmg;
        _assetIntroducerStateV1.dmmController = __dmmController;
        _assetIntroducerStateV1.underlyingTokenValuator = __underlyingTokenValuator;
        _assetIntroducerStateV1.baseURI = __baseURI;

        _assetIntroducerStateV1.initTimestamp = uint64(block.timestamp);
        _assetIntroducerStateV1.domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPE_HASH, keccak256(bytes(NAME)), EvmUtil.getChainId(), address(this))
        );
    }

    function name() external view returns (string memory) {
        return "DMM: Asset Introducer";
    }

    function symbol() external view returns (string memory) {
        return "aDMM";
    }

    function baseURI() external view returns (string memory) {
        return _assetIntroducerStateV1.baseURI;
    }

    function setBaseURI(
        string calldata __baseURI
    )
    onlyOwnerOrGuardian
    external {
        _assetIntroducerStateV1.setBaseURI(__baseURI);
    }

    function tokenURI(
        uint256 __tokenId
    )
    requireIsValidNft(__tokenId)
    external view returns (string memory) {
        return _assetIntroducerStateV1.tokenURI(__tokenId);
    }

    function createAssetIntroducersForPrimaryMarket(
        string[] calldata __countryCodes,
        AssetIntroducerType[] calldata __introducerTypes,
        uint[] calldata __dmgPriceAmounts
    )
    external
    nonReentrant
    onlyOwnerOrGuardian
    returns (uint[] memory) {
        return _assetIntroducerStateV1.createAssetIntroducersForPrimaryMarket(
            _erc721StateV1,
            __countryCodes,
            __introducerTypes,
            __dmgPriceAmounts
        );
    }

    function setDollarAmountToManageByTokenId(
        uint __tokenId,
        uint __dollarAmountToManage
    )
    external
    requireIsValidNft(__tokenId)
    onlyOwnerOrGuardian {
        require(
            __dollarAmountToManage == uint104(__dollarAmountToManage),
            "AssetIntroducerV1::setDollarAmountToManageByTokenId: INVALID_DOLLAR_AMOUNT"
        );

        _idToAssetIntroducer[__tokenId].dollarAmountToManage = uint104(__dollarAmountToManage);
    }

    function setDollarAmountToManageByCountryCodeAndIntroducerType(
        string calldata __countryCode,
        AssetIntroducerType __introducerType,
        uint __dollarAmountToManage
    )
    external
    onlyOwnerOrGuardian {
        require(
            __dollarAmountToManage == uint104(__dollarAmountToManage),
            "AssetIntroducerV1::setDollarAmountToManageByTokenId: INVALID_DOLLAR_AMOUNT"
        );

        bytes3 rawCountryCode = _verifyAndConvertCountryCodeToBytes(__countryCode);
        uint[] memory tokenIds = _countryCodeToAssetIntroducerTypeToTokenIdsMap[rawCountryCode][uint8(__introducerType)];
        for (uint i = 0; i < tokenIds.length; i++) {
            _idToAssetIntroducer[tokenIds[i]].dollarAmountToManage = uint104(__dollarAmountToManage);
        }
    }

    // *************************
    // ***** User Functions
    // *************************

    function buyAssetIntroducerSlot(
        uint __tokenId
    )
    external
    nonReentrant
    requireIsValidNft(__tokenId)
    requireIsPrimaryMarketNft(__tokenId)
    returns (bool) {
        _buyAssetIntroducer(__tokenId, msg.sender, msg.sender);
        return true;
    }

    function nonceOf(
        address user
    ) external view returns (uint) {
        return _ownerToNonceMap[user];
    }

    function buyAssetIntroducerSlotBySig(
        uint __tokenId,
        address __recipient,
        uint __nonce,
        uint __expiry,
        uint8 __v,
        bytes32 __r,
        bytes32 __s
    )
    external
    nonReentrant
    requireIsValidNft(__tokenId)
    requireIsPrimaryMarketNft(__tokenId)
    returns (bool) {
        address signer;
        {
            bytes32 structHash = keccak256(abi.encode(BUY_ASSET_INTRODUCER_TYPE_HASH, __tokenId, __nonce, __expiry));
            signer = AssetIntroducerV1Lib.validateOfflineSignature(this, structHash, __nonce, __expiry, __v, __r, __s);
            _ownerToNonceMap[signer]++;
        }
        _buyAssetIntroducer(__tokenId, signer, __recipient);
        return true;
    }

    function buyAssetIntroducerSlotBySigWithDmgPermit(
        uint __tokenId,
        address __recipient,
        uint __nonce,
        uint __expiry,
        uint8 __v,
        bytes32 __r,
        bytes32 __s,
        DmgApprovalStruct memory dmgApprovalStruct
    )
    public
    nonReentrant
    requireIsValidNft(__tokenId)
    requireIsPrimaryMarketNft(__tokenId)
    returns (bool) {
        IDMGToken(_dmg).approveBySig(
            dmgApprovalStruct.spender,
            dmgApprovalStruct.rawAmount,
            dmgApprovalStruct.nonce,
            dmgApprovalStruct.expiry,
            dmgApprovalStruct.v,
            dmgApprovalStruct.r,
            dmgApprovalStruct.s
        );

        address signer;
        {
            bytes32 structHash = keccak256(abi.encode(BUY_ASSET_INTRODUCER_TYPE_HASH, __tokenId, __nonce, __expiry));
            signer = AssetIntroducerV1Lib.validateOfflineSignature(this, structHash, __nonce, __expiry, __v, __r, __s);
            _ownerToNonceMap[signer]++;
        }

        _buyAssetIntroducer(__tokenId, signer, __recipient);
        return true;
    }

    function getCurrentVotes(
        address __owner
    ) external view returns (uint) {
        return _voteStateV1.getCurrentVotes(__owner);
    }

    function getPriorVotes(
        address __owner,
        uint __blockNumber
    )
    external
    view returns (uint128) {
        return _voteStateV1.getPriorVotes(__owner, __blockNumber);
    }


    function getDmgLockedByUser(
        address __user
    ) external view returns (uint) {
        uint[] memory tokenIds = getAllTokensOf(__user);
        uint dmgLocked = 0;
        for (uint i = 0; i < tokenIds.length; i++) {
            dmgLocked = dmgLocked.add(_idToAssetIntroducer[tokenIds[i]].dmgLocked);
        }
        return dmgLocked;
    }

    // *************************
    // ***** Misc Functions
    // *************************

    function dmg() external view returns (address) {
        return _dmg;
    }

    function dmmController() external view returns (address) {
        return _dmmController;
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparator;
    }

    function underlyingTokenValuator() external view returns (address) {
        return _underlyingTokenValuator;
    }

    function getTotalDmgLocked() external view returns (uint) {
        return _totalDmgLocked;
    }

    function getDollarAmountToManageByTokenId(
        uint __tokenId
    )
    external
    requireIsValidNft(__tokenId)
    view returns (uint) {
        return _idToAssetIntroducer[__tokenId].dollarAmountToManage;
    }

    function getDmgLockedByTokenId(
        uint __tokenId
    )
    external
    requireIsValidNft(__tokenId)
    view returns (uint) {
        return _idToAssetIntroducer[__tokenId].dmgLocked;
    }

    function getAssetIntroducerDiscount() public view returns (uint) {
        uint diff = block.timestamp.sub(_initTimestamp);
        // 18 months or 540 days
        uint discountDurationInSeconds = 86400 * 30 * 18;
        if (diff > discountDurationInSeconds) {
            // The discount expired
            return 0;
        } else {
            // Discount is 90% at t=0
            uint originalDiscount = 0.9 ether;
            return originalDiscount.mul(discountDurationInSeconds.sub(diff)).div(discountDurationInSeconds);
        }
    }

    function getAssetIntroducerPriceUsd(
        uint __tokenId
    )
    requireIsValidNft(__tokenId)
    public
    returns (uint) {
        AssetIntroducer memory assetIntroducer = _idToAssetIntroducer[__tokenId];
        uint priceUsd = _countryCodeToAssetIntroducerTypeToPriceUsd[assetIntroducer.countryCode][uint8(assetIntroducer.introducerType)];
        return priceUsd.mul(ONE_ETH.sub(getAssetIntroducerDiscount())).div(ONE_ETH);
    }

    function getAssetIntroducerPriceDmg(
        uint __tokenId
    )
    requireIsValidNft(__tokenId)
    public
    returns (uint) {
        uint dmgPriceUsd = IUnderlyingTokenValuator(_underlyingTokenValuator).getTokenValue(_dmg, 1e18);
        return getAssetIntroducerPriceUsd(__tokenId).mul(1e18).div(dmgPriceUsd);
    }

    function getAssetIntroducersByCountryCode(
        string calldata __countryCode
    ) external view returns (AssetIntroducer[] memory) {
        bytes3 countryCode = _verifyAndConvertCountryCodeToBytes(__countryCode);
        uint[] memory affiliates = _countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(AssetIntroducerType.AFFILIATE)];
        uint[] memory principals = _countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(AssetIntroducerType.PRINCIPAL)];

        AssetIntroducer[] memory assetIntroducers = new AssetIntroducer[](affiliates.length + principals.length);
        for (uint i = 0; i < affiliates.length + principals.length; i++) {
            if (i < affiliates.length) {
                assetIntroducers[i] = _idToAssetIntroducer[affiliates[i]];
            } else {
                assetIntroducers[i] = _idToAssetIntroducer[principals[i - affiliates.length]];
            }
        }
        return assetIntroducers;
    }

    function getAllAssetIntroducers() public view returns (AssetIntroducer[] memory) {
        uint nextTokenId = LINKED_LIST_GUARD;
        AssetIntroducer[] memory assetIntroducers = new AssetIntroducer[](_totalSupply);
        for (uint i = 0; i < assetIntroducers.length; i++) {
            assetIntroducers[i] = _idToAssetIntroducer[_allTokens[nextTokenId]];
            nextTokenId = _allTokens[nextTokenId];
        }
        return assetIntroducers;
    }

    function getPrimaryMarketAssetIntroducers() external view returns (AssetIntroducer[] memory) {
        AssetIntroducer[] memory allAssetIntroducers = getAllAssetIntroducers();
        uint primaryMarketCount = 0;
        for (uint i = 0; i < allAssetIntroducers.length; i++) {
            if (!allAssetIntroducers[i].isOnSecondaryMarket) {
                primaryMarketCount += 1;
            }
        }

        AssetIntroducer[] memory primaryMarketAssetIntroducers = new AssetIntroducer[](primaryMarketCount);
        uint j = 0;
        for (uint i = 0; i < allAssetIntroducers.length; i++) {
            if (!allAssetIntroducers[i].isOnSecondaryMarket) {
                primaryMarketAssetIntroducers[j++] = allAssetIntroducers[i];
            }
        }
        return primaryMarketAssetIntroducers;
    }

    function getSecondaryMarketAssetIntroducers() external view returns (AssetIntroducer[] memory) {
        AssetIntroducer[] memory allAssetIntroducers = getAllAssetIntroducers();
        uint secondaryMarketCount = 0;
        for (uint i = 0; i < allAssetIntroducers.length; i++) {
            if (allAssetIntroducers[i].isOnSecondaryMarket) {
                secondaryMarketCount += 1;
            }
        }

        AssetIntroducer[] memory secondaryMarketAssetIntroducers = new AssetIntroducer[](secondaryMarketCount);
        uint j = 0;
        for (uint i = 0; i < allAssetIntroducers.length; i++) {
            if (allAssetIntroducers[i].isOnSecondaryMarket) {
                secondaryMarketAssetIntroducers[j++] = allAssetIntroducers[i];
            }
        }
        return secondaryMarketAssetIntroducers;
    }

    function getNonceByUser(address __user) external view returns (uint) {
        return _ownerToNonceMap[__user];
    }

    function getDeployedCapitalByTokenId(
        uint __tokenId
    ) public view returns (uint) {
        return AssetIntroducerV1Lib.getDeployedCapitalByTokenId(this, __tokenId);
    }

    function getTotalWithdrawnUnderlyingByTokenId(
        uint __tokenId,
        address __underlyingToken
    ) external view returns (uint) {
        return _tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__underlyingToken];
    }

    function deactivateAssetIntroducerByTokenId(
        uint __tokenId
    )
    external
    nonReentrant
    requireIsValidNft(__tokenId)
    requireIsSecondaryMarketNft(__tokenId)
    requireIsNftOwner(__tokenId) {
        _idToAssetIntroducer[__tokenId].isAllowedToWithdrawFunds = false;
    }

    function withdrawCapitalByTokenId(
        uint __tokenId,
        address __token,
        uint __amount
    )
    external
    nonReentrant
    requireIsValidNft(__tokenId)
    requireIsSecondaryMarketNft(__tokenId)
    requireIsNftOwner(__tokenId)
    requireCanWithdrawFunds(__tokenId) {
        uint standardizedAmount = AssetIntroducerV1Lib.standardizeTokenAmountForUsdDecimals(
            __amount,
            IERC20WithDecimals(__token).decimals()
        );
        uint deployedCapital = getDeployedCapitalByTokenId(__tokenId);
        uint usdAmountToWithdraw = IUnderlyingTokenValuator(_underlyingTokenValuator).getTokenValue(__token, standardizedAmount);

        require(
            deployedCapital.add(usdAmountToWithdraw) <= _idToAssetIntroducer[__tokenId].dollarAmountToManage,
            "AssetIntroducerV1::withdrawCapitalByTokenId: AUM_OVERFLOW"
        );

        _tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token] = _tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token].add(__amount);

        IDmmController dmmController = IDmmController(_dmmController);
        uint dmmTokenId = dmmController.getTokenIdFromDmmTokenAddress(dmmController.getDmmTokenForUnderlying(__token));
        dmmController.adminWithdrawFunds(dmmTokenId, __amount);
        IERC20(__token).safeTransfer(msg.sender, __amount);
    }

    function depositCapitalByTokenId(
        uint __tokenId,
        address __token,
        uint __amount
    )
    external
    nonReentrant
    requireIsValidNft(__tokenId)
    requireIsSecondaryMarketNft(__tokenId)
    requireCanWithdrawFunds(__tokenId)
    requireIsNftOwner(__tokenId) {
        require(
            _tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token] >= __amount,
            "AssetIntroducerV1::depositCapitalByTokenId: AUM_UNDERFLOW"
        );
        _tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token] = _tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__token].sub(__amount);

        IERC20(__token).safeTransferFrom(msg.sender, address(this), __amount);

        IDmmController dmmController = IDmmController(_dmmController);
        uint dmmTokenId = dmmController.getTokenIdFromDmmTokenAddress(dmmController.getDmmTokenForUnderlying(__token));
        dmmController.adminDepositFunds(dmmTokenId, __amount);
    }

    function payInterestByTokenId(
        uint __tokenId,
        address __token,
        uint __amount
    )
    external
    nonReentrant
    requireIsValidNft(__tokenId)
    requireIsSecondaryMarketNft(__tokenId)
    requireCanWithdrawFunds(__tokenId)
    requireIsNftOwner(__tokenId) {
        IERC20(__token).safeTransferFrom(msg.sender, address(this), __amount);

        IDmmController dmmController = IDmmController(_dmmController);
        uint dmmTokenId = dmmController.getTokenIdFromDmmTokenAddress(dmmController.getDmmTokenForUnderlying(__token));
        dmmController.adminDepositFunds(dmmTokenId, __amount);
    }

    // *************************
    // ***** Internal Functions
    // *************************

    function _transfer(
        address __to,
        uint256 __tokenId,
        bool __shouldAllowTransferIntoThisContract
    )
    internal {
        // The token must be unactivated in order to withdraw funds
        AssetIntroducer memory assetIntroducer = _idToAssetIntroducer[__tokenId];
        require(
            !assetIntroducer.isAllowedToWithdrawFunds,
            "AssetIntroducerV1::_transfer: TRANSFER_DISABLED"
        );

        // Get the "from" address (the owner) before effectuating the transfer via the call to "super"
        address from = _idToOwnerMap[__tokenId];
        super._transfer(__to, __tokenId, __shouldAllowTransferIntoThisContract);
        _voteStateV1.moveDelegates(from, __to, assetIntroducer.dmgLocked);
    }

    function _verifyAndConvertCountryCodeToBytes(
        string memory __countryCode
    ) internal pure returns (bytes3) {
        require(
            bytes(__countryCode).length == 3,
            "AssetIntroducerV1::_verifyAndConvertCountryCodeToBytes: INVALID_COUNTRY_CODE"
        );
        bytes3 result;
        assembly {
            result := mload(add(__countryCode, 3))
        }
        return result;
    }

    function _buyAssetIntroducer(
        uint __tokenId,
        address __buyer,
        address __recipient
    ) internal {
        uint dmgPurchasePrice = getAssetIntroducerPriceDmg(__tokenId);
        IERC20(_dmg).safeTransferFrom(__buyer, address(this), dmgPurchasePrice);
        _totalDmgLocked = _totalDmgLocked.add(dmgPurchasePrice);

        AssetIntroducer storage introducer = _idToAssetIntroducer[__tokenId];
        introducer.isOnSecondaryMarket = true;
        introducer.dmgLocked = uint96(dmgPurchasePrice);

        _transfer(__recipient, __tokenId, false);

        emit AssetIntroducerBought(__tokenId, __buyer, __recipient, dmgPurchasePrice);
    }

}