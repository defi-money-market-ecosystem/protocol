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

import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../../../utils/EvmUtil.sol";

import "../impl/ERC721.sol";

import "./IAssetIntroducerV1.sol";

contract AssetIntroducerV1 is ERC721Token, IAssetIntroducerV1 {

    using SafeERC20 for IERC20;
    using SafeMath for uint;

    // *************************
    // ***** Constants
    // *************************

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPE_HASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the purchase struct used by the contract
    bytes32 public constant BUY_ASSET_INTRODUCER_TYPE_HASH = keccak256("BuyAssetIntroducer(uint256 purchasePrice,uint256 nonce,uint256 expiry)");

    // *************************
    // ***** Admin Functions
    // *************************

    function initialize(
        address __owner,
        address __guardian
    )
    public
    initializer {
        IOwnableOrGuardian.initialize(__owner, __guardian);

        _domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPE_HASH, keccak256(bytes(NAME)), EvmUtil.getChainId(), address(this))
        );
    }

    function createAssetIntroducersForPrimaryMarket(
        string[] calldata __countryCodes,
        AssetIntroducerData.AssetIntroducerType[] calldata __introducerTypes,
        uint[] calldata __dmgPriceAmounts
    )
    external
    onlyOwnerOrGuardian
    returns (uint[] memory) {
        require(
            __countryCodes.length == __introducerTypes.length,
            "AssetIntroducerV1::createAssetIntroducersForPrimaryMarket: INVALID_LENGTH"
        );
        require(
            __countryCodes.length == __dmgPriceAmounts.length,
            "AssetIntroducerV1::createAssetIntroducersForPrimaryMarket: INVALID_LENGTH"
        );

        uint[] memory tokenIds = new uint[](__countryCodes.length);

        for (uint i = 0; i < __countryCodes.length; i++) {
            bytes3 countryCode = _verifyAndConvertCountryCodeToBytes(__countryCodes[i]);
            uint nonce = _countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(__introducerTypes[i])].length;
            tokenIds[i] = uint(keccak256(abi.encodePacked(countryCode, uint8(__introducerTypes[i]), nonce)));

            _idToAssetIntroducer[tokenIds[i]] = AssetIntroducer({
            countryCode : countryCode,
            introducerType : __introducerTypes[i],
            isOnSecondaryMarket : false,
            dmgLocked : 0,
            dollarAmountToManage : 0
            });

            _mint(address(this), tokenIds[i]);
        }

        return tokenIds;
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
        AssetIntroducerData.AssetIntroducerType __introducerType,
        uint __dollarAmountToManage
    )
    external
    onlyOwnerOrGuardian {
        require(
            __dollarAmountToManage == uint104(__dollarAmountToManage),
            "AssetIntroducerV1::setDollarAmountToManageByTokenId: INVALID_DOLLAR_AMOUNT"
        );

        bytes3 rawCountryCode = _verifyAndConvertCountryCodeToBytes(__countryCode);
        uint[] memory tokenIds = _countryCodeToAssetIntroducerTypeToTokenIdsMap[rawCountryCode][__introducerType];
        for (uint i = 0; i < tokenIds.length; i++) {
            _idToAssetIntroducer[tokenIds[i]].dollarAmountToManage = uint104(__dollarAmountToManage);
        }
    }

    // *************************
    // ***** User Functions
    // *************************

    /**
     * Buys the slot for the appropriate amount of DMG, by attempting to transfer the DMG from `msg.sender` to this
     * contract
     */
    function buyAssetIntroducerSlot(
        uint __tokenId
    )
    external
    requireIsValidNft(__tokenId)
    requireIsPrimaryMarketNft(__tokenId)
    returns (bool) {
        _buyAssetIntroducer(msg.sender, __tokenId);
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
        uint __amount,
        uint __nonce,
        uint __expiry,
        uint8 __v,
        bytes32 __r,
        bytes32 __s
    )
    external
    requireIsValidNft(__tokenId)
    requireIsPrimaryMarketNft(__tokenId)
    returns (bool) {
        bytes32 structHash = keccak256(abi.encode(BUY_ASSET_INTRODUCER_TYPE_HASH, __amount, __nonce, __expiry));
        address signer = _validateOfflineSignature(structHash, __nonce, __expiry, __v, __r, __s);
        _buyAssetIntroducer(signer, __tokenId);
        return true;
    }

    function buyAssetIntroducerSlotBySigWithDmgPermit(
        uint __tokenId,
        address __recipient,
        uint __amount,
        uint __nonce,
        uint __expiry,
        uint8 __v,
        bytes32 __r,
        bytes32 __s,
        DmgApprovalStruct memory dmgApprovalStruct
    )
    public
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

        bytes32 structHash = keccak256(abi.encode(BUY_ASSET_INTRODUCER_TYPE_HASH, __amount, __nonce, __expiry));
        address signer = _validateOfflineSignature(structHash, __nonce, __expiry, __v, __r, __s);

        _buyAssetIntroducer(signer, __tokenId);
        return true;
    }

    function getAssetIntroducerPrice(
        uint __tokenId
    ) public returns (uint);

    function getCurrentVotes(
        address __owner
    ) external view returns (uint);

    function getPriorVotes(
        address __owner,
        uint __blockNumber
    ) external view returns (uint);

    function getDmgLockedByUser(
        address __user
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
        uint __tokenId
    ) external view returns (uint);

    /**
     * @return  The amount of DMG that this asset introducer has locked in order to maintain a valid status as an asset
     *          introducer.
     */
    function getDmgLockedByTokenId(
        uint __tokenId
    ) external view returns (uint);

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
            result := mload(add(countryCode, 3))
        }
        return result;
    }

    function _validateOfflineSignature(
        bytes32 __structHash,
        uint __nonce,
        uint __expiry,
        uint8 __v,
        bytes32 __r,
        bytes32 __s
    )
    internal
    returns (address signer) {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, __structHash));
        signer = ecrecover(digest, __v, __r, __s);
        require(signer != address(0), "AssetIntroducerV1::_validateOfflineSignature: invalid signature");
        require(__nonce == _ownerToNonceMap[signer]++, "AssetIntroducerV1::_validateOfflineSignature: invalid nonce");
        require(now <= __expiry, "AssetIntroducerV1::_validateOfflineSignature: signature expired");

        emit SignatureValidated(signer, __nonce);
    }

    function _buyAssetIntroducer(
        address __buyer,
        uint __tokenId
    ) internal {
        uint dmgPurchasePrice = getAssetIntroducerPrice(__tokenId);
        IERC20(_dmg).safeTransferFrom(__buyer, address(this), dmgPurchasePrice);
        _totalDmgLocked = _totalDmgLocked.add(dmgPurchasePrice);

        AssetIntroducer storage introducer = _idToAssetIntroducer[__tokenId];
        introducer.isOnSecondaryMarket = true;
        introducer.dmgLocked = dmgPurchasePrice;

        _transfer(__buyer, __tokenId);

        emit AssetIntroducerBought(__tokenId, __buyer, dmgPurchasePrice);
    }

}