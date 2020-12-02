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

import "../../../../node_modules/@openzeppelin/upgrades/contracts/utils/Address.sol";
import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../impl/AssetIntroducerVotingLib.sol";

import "../interfaces/IERC721.sol";
import "../interfaces/IERC721Enumerable.sol";
import "../interfaces/IERC721Metadata.sol";
import "../interfaces/IERC721TokenReceiver.sol";
import "../interfaces/IOpenSeaProxyRegistry.sol";

import "../AssetIntroducerData.sol";

/**
 * @dev Implementation of ERC-721 non-fungible token standard.
 */
library ERC721TokenLib {

    using SafeMath for uint;
    using OpenZeppelinUpgradesAddress for address;
    using AssetIntroducerVotingLib for AssetIntroducerData.VoteStateV1;

    // *************************
    // ***** Events
    // *************************

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event Approval(
        address indexed owner,
        address indexed operator,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event BaseURIChanged(string newBaseURI);

    // *************************
    // ***** Constants
    // *************************

    /**
     * @dev Magic value of a smart contract that can receive NFT.
     * Equal to: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")).
     */
    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    bytes4 internal constant ERC721_INTERFACE_ID = 0x80ac58cd;

    /// The entry-point into the linked list
    uint internal constant LINKED_LIST_GUARD = uint(1);

    // *************************
    // ***** Functions
    // *************************

    function linkedListGuard() public pure returns (uint) {
        return LINKED_LIST_GUARD;
    }

    function initialize(
        AssetIntroducerData.ERC721StateV1 storage __state,
        string memory __baseURI,
        address __openSeaProxyRegistry
    )
    public {
        __state.baseURI = __baseURI;
        __state.openSeaProxyRegistry = __openSeaProxyRegistry;
        __state.interfaceIdToIsSupportedMap[ERC721_INTERFACE_ID] = true;
        __state.lastTokenId = LINKED_LIST_GUARD;
    }

    function setBaseURI(
        AssetIntroducerData.ERC721StateV1 storage __state,
        string calldata __baseURI
    ) external {
        __state.baseURI = __baseURI;
        emit BaseURIChanged(__baseURI);
    }

    function tokenURI(
        AssetIntroducerData.ERC721StateV1 storage __state,
        uint __tokenId
    ) public view returns (string memory) {
        bytes memory reversedNumber = new bytes(96);
        uint stringLength = 0;
        while (__tokenId != 0) {
            uint remainder = __tokenId % 10;
            __tokenId = __tokenId / 10;
            reversedNumber[stringLength++] = byte(uint8(48 + remainder));
        }
        bytes memory tokenIdBytes = new bytes(stringLength);
        for (uint j = 0; j < stringLength; j++) {
            tokenIdBytes[j] = reversedNumber[stringLength - 1 - j];
        }
        return string(abi.encodePacked(__state.baseURI, tokenIdBytes));
    }

    function supportsInterface(
        AssetIntroducerData.ERC721StateV1 storage __state,
        bytes4 __interfaceId
    )
    public view returns (bool) {
        return __interfaceId != 0xffffffff && __state.interfaceIdToIsSupportedMap[__interfaceId];
    }

    function safeTransferFrom(
        AssetIntroducerData.ERC721StateV1 storage __state,
        AssetIntroducerData.VoteStateV1 storage __voteState,
        address __from,
        address __to,
        uint256 __tokenId,
        bytes memory __data,
        AssetIntroducerData.AssetIntroducer memory __assetIntroducer
    )
    public {
        address tokenOwner = __state.idToOwnerMap[__tokenId];
        require(
            tokenOwner == __from,
            "ERC721TokenLib::_safeTransferFrom NOT_OWNER"
        );
        require(
            __to != address(0),
            "ERC721TokenLib::_safeTransferFrom INVALID_RECIPIENT"
        );

        _transfer(__state, __voteState, __to, __tokenId, __assetIntroducer);

        _verifyCanReceiveTokens(__from, __to, __tokenId, __data);
    }

    function transferFrom(
        AssetIntroducerData.ERC721StateV1 storage __state,
        AssetIntroducerData.VoteStateV1 storage __voteState,
        address __from,
        address __to,
        uint256 __tokenId,
        AssetIntroducerData.AssetIntroducer memory __assetIntroducer
    )
    public {
        address tokenOwner = __state.idToOwnerMap[__tokenId];

        require(
            tokenOwner == __from,
            "ERC721TokenLib::transferFrom: NOT_OWNER"
        );
        require(
            __to != address(0),
            "ERC721TokenLib::transferFrom: INVALID_RECIPIENT"
        );

        _transfer(__state, __voteState, __to, __tokenId, __assetIntroducer);

        _verifyCanReceiveTokens(__from, __to, __tokenId, "");
    }

    function mint(
        AssetIntroducerData.ERC721StateV1 storage __state,
        AssetIntroducerData.VoteStateV1 storage __voteState,
        address __to,
        uint __tokenId,
        uint128 __dmgLocked
    )
    public {
        require(
            __to != address(0),
            "ERC721TokenLib::mint INVALID_RECIPIENT"
        );
        require(
            __state.idToOwnerMap[__tokenId] == address(0),
            "ERC721TokenLib::mint TOKEN_ALREADY_EXISTS"
        );

        _addTokenToNewOwner(__state, __to, __tokenId);

        __state.allTokens[__state.lastTokenId] = __tokenId;
        __state.lastTokenId = __tokenId;

        __state.totalSupply += 1;

        AssetIntroducerVotingLib.moveDelegates(__voteState, address(0), __to, __dmgLocked);

        emit Transfer(address(0), __to, __tokenId);
    }

    function burn(
        AssetIntroducerData.ERC721StateV1 storage __state,
        AssetIntroducerData.VoteStateV1 storage __voteState,
        uint __tokenId,
        uint128 __dmgLocked
    )
    public {
        address tokenOwner = __state.idToOwnerMap[__tokenId];
        _clearApproval(__state, __tokenId);
        _removeToken(__state, tokenOwner, __tokenId);

        uint totalSupply = __state.totalSupply;
        uint previousTokenId = LINKED_LIST_GUARD;
        for (uint i = 0; i < totalSupply; i++) {
            if (__state.allTokens[previousTokenId] == __tokenId) {
                __state.allTokens[previousTokenId] = __state.allTokens[__tokenId];
                break;
            }
            previousTokenId = __state.allTokens[previousTokenId];
        }

        if (__tokenId == __state.lastTokenId) {
            __state.lastTokenId = __state.allTokens[previousTokenId];
        }

        __state.totalSupply -= 1;

        AssetIntroducerVotingLib.moveDelegates(__voteState, tokenOwner, address(0), __dmgLocked);

        emit Transfer(tokenOwner, address(0), __tokenId);
    }

    function approve(
        AssetIntroducerData.ERC721StateV1 storage __state,
        address __spender,
        uint256 __tokenId
    )
    public {
        address tokenOwner = __state.idToOwnerMap[__tokenId];
        require(
            __spender != tokenOwner,
            "ERC721TokenLib::approve: SPENDER_MUST_NOT_BE_OWNER"
        );

        __state.idToSpenderMap[__tokenId] = __spender;
        emit Approval(tokenOwner, __spender, __tokenId);
    }

    function setApprovalForAll(
        AssetIntroducerData.ERC721StateV1 storage __state,
        address __operator,
        bool _isApproved
    )
    public {
        __state.ownerToOperatorToIsApprovedMap[msg.sender][__operator] = _isApproved;
        emit ApprovalForAll(msg.sender, __operator, _isApproved);
    }

    function balanceOf(
        AssetIntroducerData.ERC721StateV1 storage __state,
        address __owner
    )
    public view returns (uint) {
        require(
            __owner != address(0),
            "ERC721TokenLib::balanceOf: INVALID_OWNER"
        );
        return __state.ownerToTokenCount[__owner];
    }

    function tokenByIndex(
        AssetIntroducerData.ERC721StateV1 storage __state,
        uint __index
    )
    public view returns (uint) {
        require(
            __index < __state.totalSupply,
            "ERC721TokenLib::tokenByIndex: INVALID_INDEX"
        );

        uint tokenId = LINKED_LIST_GUARD;
        for (uint i = 0; i <= __index; i++) {
            tokenId = __state.allTokens[tokenId];
        }

        return tokenId;
    }

    function tokenOfOwnerByIndex(
        AssetIntroducerData.ERC721StateV1 storage __state,
        address __owner,
        uint __index
    )
    public view returns (uint) {
        require(
            __index < balanceOf(__state, __owner),
            "ERC721TokenLib::tokenOfOwnerByIndex: INVALID_INDEX"
        );

        uint tokenId = LINKED_LIST_GUARD;
        for (uint i = 0; i <= __index; i++) {
            tokenId = __state.ownerToTokenIds[__owner][tokenId];
        }
        return tokenId;
    }

    function ownerOf(
        AssetIntroducerData.ERC721StateV1 storage __state,
        uint __tokenId
    )
    public view returns (address) {
        address owner = __state.idToOwnerMap[__tokenId];
        require(
            owner != address(0),
            "ERC721TokenLib::ownerOf INVALID_TOKEN"
        );
        return owner;
    }

    function getApproved(
        AssetIntroducerData.ERC721StateV1 storage __state,
        uint256 __tokenId
    )
    public view returns (address) {
        return __state.idToSpenderMap[__tokenId];
    }

    function isApprovedForAll(
        AssetIntroducerData.ERC721StateV1 storage __state,
        address __owner,
        address __operator
    )
    public view returns (bool) {
        if (IOpenSeaProxyRegistry(__state.openSeaProxyRegistry).proxies(__owner) == __operator) {
            return true;
        }

        return __state.ownerToOperatorToIsApprovedMap[__owner][__operator];
    }

    function getAllTokensOf(
        AssetIntroducerData.ERC721StateV1 storage __state,
        address __owner
    )
    public view returns (uint[] memory) {
        uint tokenCount = __state.ownerToTokenCount[__owner];
        uint[] memory tokens = new uint[](tokenCount);

        uint tokenId = LINKED_LIST_GUARD;
        for (uint i = 0; i < tokenCount; i++) {
            tokenId = __state.ownerToTokenIds[__owner][tokenId];
            tokens[i] = tokenId;
        }

        return tokens;
    }

    // ******************************
    // ***** Internal Functions
    // ******************************

    /**
     * @dev Actually preforms the transfer. Checks that "__to" is not this contract
     * @param __to Address of a new owner.
     * @param __tokenId The NFT that is being transferred.
     */
    function _transfer(
        AssetIntroducerData.ERC721StateV1 storage __state,
        AssetIntroducerData.VoteStateV1 storage __voteState,
        address __to,
        uint256 __tokenId,
        AssetIntroducerData.AssetIntroducer memory assetIntroducer
    )
    internal {
        // The token must be unactivated in order to withdraw funds
        require(
            !assetIntroducer.isAllowedToWithdrawFunds,
            "AssetIntroducerV1::_transfer: TRANSFER_DISABLED"
        );

        // Get the "from" address (the owner) before effectuating the transfer via the call to "super"
        address from = __state.idToOwnerMap[__tokenId];
        __voteState.moveDelegates(from, __to, assetIntroducer.dmgLocked);

        _clearApproval(__state, __tokenId);

        _removeToken(__state, from, __tokenId);
        _addTokenToNewOwner(__state, __to, __tokenId);

        emit Transfer(from, __to, __tokenId);
    }

    /**
     * @dev Removes a NFT from owner.
     * @notice Use and override this function with caution. Wrong usage can have serious consequences.
     * @param __from Address from which we want to remove the NFT.
     * @param __tokenId Which NFT we want to remove.
     */
    function _removeToken(
        AssetIntroducerData.ERC721StateV1 storage __state,
        address __from,
        uint256 __tokenId
    )
    internal {
        require(
            __state.idToOwnerMap[__tokenId] == __from,
            "ERC721TokenLib::_removeToken: NOT_OWNER"
        );

        __state.ownerToTokenCount[__from] = __state.ownerToTokenCount[__from] - 1;
        uint previousTokenId = LINKED_LIST_GUARD;
        uint indexedTokenId = __state.ownerToTokenIds[__from][previousTokenId];

        while (indexedTokenId != uint(0)) {
            if (indexedTokenId == __tokenId) {
                uint nextTokenId = __state.ownerToTokenIds[__from][__tokenId];
                __state.ownerToTokenIds[__from][previousTokenId] = nextTokenId;
                delete __state.ownerToTokenIds[__from][__tokenId];
                break;
            }
            // Proceed to the next element in the linked list
            previousTokenId = indexedTokenId;
            indexedTokenId = __state.ownerToTokenIds[__from][indexedTokenId];
        }

        delete __state.idToOwnerMap[__tokenId];
    }

    /**
     * @dev Assigns a new NFT to owner.
     * @notice Use and override this function with caution. Wrong usage can have serious consequences.
     * @param __to Address to which we want to add the NFT.
     * @param __tokenId Which NFT we want to add.
     */
    function _addTokenToNewOwner(
        AssetIntroducerData.ERC721StateV1 storage __state,
        address __to,
        uint256 __tokenId
    )
    internal {
        require(
            __state.idToOwnerMap[__tokenId] == address(0),
            "ERC721TokenLib::_addTokenToNewOwner TOKEN_ALREADY_EXISTS"
        );

        __state.idToOwnerMap[__tokenId] = __to;
        __state.ownerToTokenCount[__to] = __state.ownerToTokenCount[__to] + 1;

        /// Append the token to the end of the linked list of the owner.
        uint previousIndex = LINKED_LIST_GUARD;
        uint indexedTokenId = __state.ownerToTokenIds[__to][previousIndex];

        while (indexedTokenId != uint(0)) {
            previousIndex = indexedTokenId;
            indexedTokenId = __state.ownerToTokenIds[__to][indexedTokenId];
        }
        __state.ownerToTokenIds[__to][previousIndex] = __tokenId;
    }

    /**
     * @dev Clears the current approval of a given NFT ID.
     * @param __tokenId ID of the NFT to be transferred.
     */
    function _clearApproval(
        AssetIntroducerData.ERC721StateV1 storage __state,
        uint256 __tokenId
    )
    internal {
        if (__state.idToSpenderMap[__tokenId] != address(0)) {
            delete __state.idToSpenderMap[__tokenId];
        }
    }

    function _verifyCanReceiveTokens(
        address __from,
        address __to,
        uint __tokenId,
        bytes memory __data
    ) internal {
        if (__to.isContract()) {
            bytes memory callData = abi.encodeWithSelector(IERC721TokenReceiver(__to).onERC721Received.selector, msg.sender, __from, __tokenId, __data);
            (bool success, bytes memory returnData) = address(__to).call(callData);
            require(
                success && abi.decode(returnData, (bytes4)) == MAGIC_ON_ERC721_RECEIVED,
                "ERC721TokenLib::_verifyCanReceiveTokens: UNABLE_TO_RECEIVE_TOKEN"
            );
        }
    }

}