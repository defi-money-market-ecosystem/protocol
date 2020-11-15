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
import "../impl/ERC721.sol";

import "./IAssetIntroducerV1.sol";

contract AssetIntroducerV1 is ERC721Token, IAssetIntroducerV1 {

    using SafeERC20 for IERC20;
    using SafeBitMath for uint128;
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
        ERC721Token.initialize();
        IOwnableOrGuardian.initialize(__owner, __guardian);

        _domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPE_HASH, keccak256(bytes(NAME)), EvmUtil.getChainId(), address(this))
        );
    }

    function name() external view returns (string memory) {
        return "Asset Introducer";
    }

    function tokenURI(
        uint256 __tokenId
    )
    external
    view returns (string memory) {
        return "";
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

            _countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(__introducerTypes[i])].push(tokenIds[i]);

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
        uint[] memory tokenIds = _countryCodeToAssetIntroducerTypeToTokenIdsMap[rawCountryCode][uint8(__introducerType)];
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
    )
    requireIsValidNft(__tokenId)
    public
    returns (uint) {
        // TODO
        return 0;
    }

    function getCurrentVotes(
        address __owner
    ) external view returns (uint) {
        uint64 checkpointCount = _ownerToCheckpointCountMap[__owner];
        return checkpointCount > 0 ? _ownerToCheckpointIndexToCheckpointMap[__owner][checkpointCount - 1].votes : 0;
    }

    function getPriorVotes(
        address __owner,
        uint __blockNumber
    )
    external
    view returns (uint128) {
        require(
            __blockNumber < block.number,
            "AssetIntroducerV1::getPriorVotes: not yet determined"
        );

        uint64 checkpointCount = _ownerToCheckpointCountMap[__owner];
        if (checkpointCount == 0) {
            return 0;
        }

        // First check most recent balance
        if (_ownerToCheckpointIndexToCheckpointMap[__owner][checkpointCount - 1].fromBlock <= __blockNumber) {
            return _ownerToCheckpointIndexToCheckpointMap[__owner][checkpointCount - 1].votes;
        }

        // Next check implicit zero balance
        if (_ownerToCheckpointIndexToCheckpointMap[__owner][0].fromBlock > __blockNumber) {
            return 0;
        }

        uint64 lower = 0;
        uint64 upper = checkpointCount - 1;
        while (upper > lower) {
            // ceil, avoiding overflow
            uint64 center = upper - (upper - lower) / 2;
            Checkpoint memory checkpoint = _ownerToCheckpointIndexToCheckpointMap[__owner][center];
            if (checkpoint.fromBlock == __blockNumber) {
                return checkpoint.votes;
            } else if (checkpoint.fromBlock < __blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return _ownerToCheckpointIndexToCheckpointMap[__owner][lower].votes;
    }


    function getDmgLockedByUser(
        address __user
    ) external view returns (uint) {
        uint[] memory tokenIds = getAllTokenIdsByOwner(__user);
        uint dmgLocked = 0;
        for (uint i = 0; i < tokenIds.length; i++) {
            dmgLocked = dmgLocked.add(_idToAssetIntroducer[tokenIds[i]].dmgLocked);
        }
        return dmgLocked;
    }

    // *************************
    // ***** Misc Functions
    // *************************

    /**
     * @return  The total amount of DMG locked in the asset introducer reserves
     */
    function getTotalDmgLocked() external view returns (uint) {
        return _totalDmgLocked;
    }

    /**
     * @return  The amount that this asset introducer can manager, represented in wei format (a number with 18
     *          decimals). Meaning, 10,000.25 * 1e18 == $10,000.25
     */
    function getDollarAmountToManageByTokenId(
        uint __tokenId
    )
    external
    requireIsValidNft(__tokenId)
    view returns (uint) {
        return _idToAssetIntroducer[__tokenId].dollarAmountToManage;
    }

    /**
     * @return  The amount of DMG that this asset introducer has locked in order to maintain a valid status as an asset
     *          introducer.
     */
    function getDmgLockedByTokenId(
        uint __tokenId
    )
    external
    requireIsValidNft(__tokenId)
    view returns (uint) {
        return _idToAssetIntroducer[__tokenId].dmgLocked;
    }

    function getAssetIntroducersByCountryCode(
        string calldata __countryCode
    ) external view returns (uint[] memory) {
        bytes3 countryCode = _verifyAndConvertCountryCodeToBytes(__countryCode);
        uint[] memory principalTokenIds = _countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(AssetIntroducerType.PRINCIPAL)];
        uint[] memory affiliateTokenIds = _countryCodeToAssetIntroducerTypeToTokenIdsMap[countryCode][uint8(AssetIntroducerType.AFFILIATE)];
        uint[] memory allTokenIds = new uint[](principalTokenIds.length + affiliateTokenIds.length);
        for (uint i = 0; i < allTokenIds.length; i++) {
            if (i < principalTokenIds.length) {
                allTokenIds[i] = principalTokenIds[i];
            } else {
                allTokenIds[i] = affiliateTokenIds[i - principalTokenIds.length];
            }
        }
        return allTokenIds;
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
        // Get the "from" address (the owner) before effectuating the transfer via the call to "super"
        address from = _idToOwnerMap[__tokenId];
        super._transfer(__to, __tokenId, __shouldAllowTransferIntoThisContract);
        _moveDelegates(from, __to, _idToAssetIntroducer[__tokenId].dmgLocked);
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

        require(
            signer != address(0),
            "AssetIntroducerV1::_validateOfflineSignature: INVALID_SIGNATURE"
        );
        require(
            __nonce == _ownerToNonceMap[signer]++,
            "AssetIntroducerV1::_validateOfflineSignature: INVALID_NONCE"
        );
        require(
            now <= __expiry,
            "AssetIntroducerV1::_validateOfflineSignature: EXPIRED"
        );

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
        introducer.dmgLocked = uint96(dmgPurchasePrice);

        _transfer(__buyer, __tokenId, false);

        emit AssetIntroducerBought(__tokenId, __buyer, dmgPurchasePrice);
    }

    function _moveDelegates(
        address fromOwner,
        address toOwner,
        uint128 amount
    ) internal {
        if (fromOwner != toOwner && amount > 0) {
            if (fromOwner != address(0)) {
                uint64 fromCheckpointCount = _ownerToCheckpointCountMap[fromOwner];
                uint128 fromVotesOld = fromCheckpointCount > 0 ? _ownerToCheckpointIndexToCheckpointMap[fromOwner][fromCheckpointCount - 1].votes : 0;
                uint128 fromVotesNew = SafeBitMath.sub128(
                    fromVotesOld,
                    amount,
                    "AssetIntroducerV1::_moveVotes: VOTE_UNDERFLOW"
                );
                _writeCheckpoint(fromOwner, fromCheckpointCount, fromVotesOld, fromVotesNew);
            }

            if (toOwner != address(0)) {
                uint64 toCheckpointCount = _ownerToCheckpointCountMap[toOwner];
                uint128 toVotesOld = toCheckpointCount > 0 ? _ownerToCheckpointIndexToCheckpointMap[toOwner][toCheckpointCount - 1].votes : 0;
                uint128 toVotesNew = SafeBitMath.add128(
                    toVotesOld,
                    amount,
                    "AssetIntroducerV1::_moveVotes: VOTE_OVERFLOW"
                );
                _writeCheckpoint(toOwner, toCheckpointCount, toVotesOld, toVotesNew);
            }
        }
    }


    function _writeCheckpoint(
        address owner,
        uint64 checkpointCount,
        uint128 oldVotes,
        uint128 newVotes
    ) internal {
        uint64 blockNumber = SafeBitMath.safe64(
            block.number,
            "AssetIntroducerV1::_writeCheckpoint: INVALID_BLOCK_NUMBER"
        );

        if (checkpointCount > 0 && _ownerToCheckpointIndexToCheckpointMap[owner][checkpointCount - 1].fromBlock == blockNumber) {
            _ownerToCheckpointIndexToCheckpointMap[owner][checkpointCount - 1].votes = newVotes;
        } else {
            _ownerToCheckpointIndexToCheckpointMap[owner][checkpointCount] = Checkpoint(blockNumber, newVotes);
            _ownerToCheckpointCountMap[owner] = checkpointCount + 1;
        }

        emit DelegateVotesChanged(owner, oldVotes, newVotes);
    }

}