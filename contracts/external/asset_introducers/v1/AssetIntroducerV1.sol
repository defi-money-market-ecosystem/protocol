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

import "../interfaces/IAssetIntroducerDiscount.sol";

import "./IAssetIntroducerV1.sol";
import "./IAssetIntroducerV1Initializable.sol";
import "./AssetIntroducerV1UserLib.sol";
import "./AssetIntroducerV1AdminLib.sol";

contract AssetIntroducerV1 is ERC721Token, IAssetIntroducerV1, IAssetIntroducerV1Initializable {

    using AssetIntroducerV1UserLib for *;
    using AssetIntroducerV1AdminLib for *;
    using AssetIntroducerVotingLib for *;
    using SafeERC20 for IERC20;
    using SafeBitMath for uint128;
    using SafeMath for uint;

    // *************************
    // ***** Constants
    // *************************

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPE_HASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the purchase struct used by the contract
    bytes32 public constant BUY_ASSET_INTRODUCER_TYPE_HASH = keccak256("BuyAssetIntroducer(uint256 tokenId,uint256 nonce,uint256 expiry)");

    string internal constant NAME = "DMM: Asset Introducer";

    // *************************
    // ***** Admin Functions
    // *************************

    function initialize(
        string calldata __baseURI,
        address __openSeaProxyRegistry,
        address __owner,
        address __guardian,
        address __dmg,
        address __dmmController,
        address __underlyingTokenValuator,
        address __assetIntroducerDiscount
    )
    external
    initializer {
        ERC721Token.initialize(__baseURI, __openSeaProxyRegistry);
        IOwnableOrGuardian.initialize(__owner, __guardian);

        _assetIntroducerStateV1.dmg = __dmg;
        _assetIntroducerStateV1.dmmController = __dmmController;
        _assetIntroducerStateV1.underlyingTokenValuator = __underlyingTokenValuator;
        _assetIntroducerStateV1.assetIntroducerDiscount = __assetIntroducerDiscount;

        _assetIntroducerStateV1.initTimestamp = uint64(block.timestamp);
        _assetIntroducerStateV1.domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPE_HASH, keccak256(bytes(NAME)), EvmUtil.getChainId(), address(this))
        );
    }

    function name() external view returns (string memory) {
        return NAME;
    }

    function symbol() external view returns (string memory) {
        return "aDMM";
    }

    function createAssetIntroducersForPrimaryMarket(
        string[] calldata __countryCodes,
        AssetIntroducerType[] calldata __introducerTypes
    )
    external
    nonReentrant
    onlyOwnerOrGuardian
    returns (uint[] memory) {
        return _assetIntroducerStateV1.createAssetIntroducersForPrimaryMarket(
            _erc721StateV1,
            _voteStateV1,
            __countryCodes,
            __introducerTypes
        );
    }

    function setDollarAmountToManageByTokenId(
        uint __tokenId,
        uint __dollarAmountToManage
    )
    external
    requireIsValidNft(__tokenId)
    onlyOwnerOrGuardian {
        _assetIntroducerStateV1.setDollarAmountToManageByTokenId(__tokenId, __dollarAmountToManage);
    }

    function setDollarAmountToManageByCountryCodeAndIntroducerType(
        string calldata __countryCode,
        AssetIntroducerType __introducerType,
        uint __dollarAmountToManage
    )
    external
    onlyOwnerOrGuardian {
        _assetIntroducerStateV1.setDollarAmountToManageByCountryCodeAndIntroducerType(
            __countryCode,
            __introducerType,
            __dollarAmountToManage
        );
    }

    function setAssetIntroducerDiscount(
        address __assetIntroducerDiscount
    )
    external
    onlyOwnerOrGuardian {
        _assetIntroducerStateV1.setAssetIntroducerDiscount(__assetIntroducerDiscount);
    }

    function setAssetIntroducerPrice(
        string calldata __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType,
        uint __priceUsd
    )
    external
    onlyOwnerOrGuardian {
        _assetIntroducerStateV1.setAssetIntroducerPrice(__countryCode, __introducerType, __priceUsd);
    }

    // *************************
    // ***** User Functions
    // *************************

    function getNextAssetIntroducerTokenId(
        string calldata __countryCode,
        AssetIntroducerType __introducerType
    ) external view returns (uint) {
        bytes3 countryCode = AssetIntroducerV1UserLib._verifyAndConvertCountryCodeToBytes(__countryCode);
        uint8 introducerType = uint8(__introducerType);
        return _assetIntroducerStateV1._getAssetIntroducerTokenId(countryCode, introducerType);
    }

    function buyAssetIntroducerSlot(
        uint __tokenId
    )
    external
    nonReentrant
    requireIsValidNft(__tokenId)
    requireIsPrimaryMarketNft(__tokenId)
    returns (bool) {
        _assetIntroducerStateV1.buyAssetIntroducer(__tokenId, msg.sender, msg.sender, _erc721StateV1, _voteStateV1);
        return true;
    }

    function nonceOf(
        address user
    ) external view returns (uint) {
        return _assetIntroducerStateV1.ownerToNonceMap[user];
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
            signer = _assetIntroducerStateV1.validateOfflineSignature(structHash, __nonce, __expiry, __v, __r, __s);
        }
        _assetIntroducerStateV1.buyAssetIntroducer(__tokenId, __recipient, signer, _erc721StateV1, _voteStateV1);
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
        _assetIntroducerStateV1.performDmgApproval(dmgApprovalStruct);

        address signer;
        {
            bytes32 structHash = keccak256(abi.encode(BUY_ASSET_INTRODUCER_TYPE_HASH, __tokenId, __nonce, __expiry));
            signer = _assetIntroducerStateV1.validateOfflineSignature(structHash, __nonce, __expiry, __v, __r, __s);
        }

        _assetIntroducerStateV1.buyAssetIntroducer(__tokenId, __recipient, signer, _erc721StateV1, _voteStateV1);
        return true;
    }

    function performDmgApproval(
        DmgApprovalStruct memory dmgApprovalStruct
    ) internal {
        IDMGToken(_assetIntroducerStateV1.dmg).approveBySig(
            dmgApprovalStruct.spender,
            dmgApprovalStruct.rawAmount,
            dmgApprovalStruct.nonce,
            dmgApprovalStruct.expiry,
            dmgApprovalStruct.v,
            dmgApprovalStruct.r,
            dmgApprovalStruct.s
        );
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
        return _assetIntroducerStateV1.getDmgLockedByUser(_erc721StateV1, __user);
    }

    // *************************
    // ***** Misc Functions
    // *************************

    function dmg() external view returns (address) {
        return _assetIntroducerStateV1.dmg;
    }

    function dmmController() external view returns (address) {
        return _assetIntroducerStateV1.dmmController;
    }

    function initTimestamp() external view returns (uint64) {
        return _assetIntroducerStateV1.initTimestamp;
    }

    function openSeaProxyRegistry() external view returns (address) {
        return _erc721StateV1.openSeaProxyRegistry;
    }

    function domainSeparator() external view returns (bytes32) {
        return _assetIntroducerStateV1.domainSeparator;
    }

    function underlyingTokenValuator() external view returns (address) {
        return _assetIntroducerStateV1.underlyingTokenValuator;
    }

    function assetIntroducerDiscount() external view returns (address) {
        return _assetIntroducerStateV1.assetIntroducerDiscount;
    }

    function getTotalDmgLocked() external view returns (uint) {
        return _assetIntroducerStateV1.totalDmgLocked;
    }

    function getDollarAmountToManageByTokenId(
        uint __tokenId
    )
    external
    requireIsValidNft(__tokenId)
    view returns (uint) {
        return _assetIntroducerStateV1.idToAssetIntroducer[__tokenId].dollarAmountToManage;
    }

    function getDmgLockedByTokenId(
        uint __tokenId
    )
    external
    requireIsValidNft(__tokenId)
    view returns (uint) {
        return _assetIntroducerStateV1.idToAssetIntroducer[__tokenId].dmgLocked;
    }

    function getAssetIntroducerByTokenId(
        uint __tokenId
    )
    requireIsValidNft(__tokenId)
    external view returns (AssetIntroducerData.AssetIntroducer memory) {
        return _assetIntroducerStateV1.idToAssetIntroducer[__tokenId];
    }

    function getAssetIntroducerDiscount() public view returns (uint) {
        return _assetIntroducerStateV1.getAssetIntroducerDiscount();
    }

    function getAssetIntroducerPriceUsdByTokenId(
        uint __tokenId
    )
    requireIsValidNft(__tokenId)
    public view returns (uint) {
        return _assetIntroducerStateV1.getAssetIntroducerPriceUsdByTokenId(__tokenId);
    }

    function getAssetIntroducerPriceDmgByTokenId(
        uint __tokenId
    )
    requireIsValidNft(__tokenId)
    public view returns (uint) {
        return _assetIntroducerStateV1.getAssetIntroducerPriceDmgByTokenId(__tokenId);
    }

    function getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(
        string calldata __countryCode,
        AssetIntroducerType __introducerType
    )
    external view returns (uint) {
        return _assetIntroducerStateV1.getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(__countryCode, __introducerType);
    }

    function getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(
        string calldata __countryCode,
        AssetIntroducerType __introducerType
    )
    external view returns (uint) {
        return _assetIntroducerStateV1.getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(__countryCode, __introducerType);
    }

    function getAssetIntroducersByCountryCode(
        string calldata __countryCode
    ) external view returns (AssetIntroducer[] memory) {
        return _assetIntroducerStateV1.getAssetIntroducersByCountryCode(__countryCode);
    }

    function getAllAssetIntroducers() public view returns (AssetIntroducer[] memory) {
        return _assetIntroducerStateV1.getAllAssetIntroducers(_erc721StateV1);
    }

    function getPrimaryMarketAssetIntroducers() external view returns (AssetIntroducer[] memory) {
        return _assetIntroducerStateV1.getPrimaryMarketAssetIntroducers(_erc721StateV1);
    }

    function getSecondaryMarketAssetIntroducers() external view returns (AssetIntroducer[] memory) {
        return _assetIntroducerStateV1.getSecondaryMarketAssetIntroducers(_erc721StateV1);
    }

    function getNonceByUser(address __user) external view returns (uint) {
        return _assetIntroducerStateV1.ownerToNonceMap[__user];
    }

    function getDeployedCapitalUsdByTokenId(
        uint __tokenId
    ) public view returns (uint) {
        return _assetIntroducerStateV1.getDeployedCapitalUsdByTokenId(__tokenId);
    }

    function getTotalWithdrawnUnderlyingByTokenId(
        uint __tokenId,
        address __underlyingToken
    ) external view returns (uint) {
        return _assetIntroducerStateV1.tokenIdToUnderlyingTokenToWithdrawnAmount[__tokenId][__underlyingToken];
    }

    function deactivateAssetIntroducerByTokenId(
        uint __tokenId
    )
    external
    nonReentrant
    requireIsValidNft(__tokenId)
    requireIsSecondaryMarketNft(__tokenId)
    requireIsNftOwner(__tokenId) {
        _assetIntroducerStateV1.deactivateAssetIntroducerByTokenId(__tokenId);
    }

    function withdrawCapitalByTokenIdAndToken(
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
        _assetIntroducerStateV1.withdrawCapitalByTokenIdAndToken(__tokenId, __token, __amount);
    }

    function depositCapitalByTokenIdAndToken(
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
        _assetIntroducerStateV1.depositCapitalByTokenIdAndToken(__tokenId, __token, __amount);
    }

    function payInterestByTokenIdAndToken(
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
        _assetIntroducerStateV1.payInterestByTokenIdAndToken(__tokenId, __token, __amount);
    }

    // *************************
    // ***** Internal Functions
    // *************************

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

}