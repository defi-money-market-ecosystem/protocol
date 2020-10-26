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

import "../../../../node_modules/@openzeppelin/upgrades/contracts/Initializable.sol";
import "../../../../node_modules/@openzeppelin/upgrades/contracts/utils/Address.sol";
import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/IERC721.sol";
import "../interfaces/IERC721Enumerable.sol";
import "../interfaces/IERC721Metadata.sol";
import "../interfaces/IERC721TokenReceiver.sol";

import "../AssetIntroducerData.sol";

/**
 * @dev Implementation of ERC-721 non-fungible token standard.
 */
contract ERC721Token is IERC721, IERC721Metadata, IERC721Enumerable, AssetIntroducerData {

    using SafeMath for uint256;
    using OpenZeppelinUpgradesAddress for address;

    /**
     * @dev Magic value of a smart contract that can receive NFT.
     * Equal to: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")).
     */
    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    /**
     * @dev Guarantees that the msg.sender is an owner or operator of the given NFT.
     * @param __tokenId ID of the NFT to validate.
     */
    modifier onlyOperator(uint256 __tokenId) {
        address tokenOwner = _idToOwnerMap[__tokenId];
        require(
            tokenOwner == msg.sender || _ownerToOperatorToIsApprovedMap[tokenOwner][msg.sender],
            "ERC721: NOT_OWNER_OR_NOT_OPERATOR"
        );

        _;
    }

    /**
     * @dev Guarantees that the msg.sender is allowed to transfer NFT.
     * @param __tokenId ID of the NFT to transfer.
     */
    modifier canTransfer(uint256 __tokenId) {
        address tokenOwner = _idToOwnerMap[__tokenId];
        require(
            tokenOwner == msg.sender ||
            _idToSpenderMap[__tokenId] == msg.sender ||
            _ownerToOperatorToIsApprovedMap[tokenOwner][msg.sender],
            "ERC721: NOT_APPROVED_OR_NOT_OPERATOR"
        );

        _;
    }

    /**
     * @dev Guarantees that __tokenId is a valid Token.
     * @param __tokenId ID of the NFT to validate.
     */
    modifier onlyValidNft(uint256 __tokenId) {
        require(
            _idToOwnerMap[__tokenId] != address(0),
            "ERC721: INVALID_TOKEN"
        );

        _;
    }

    /**
     * @dev Contract constructor.
     */
    constructor() public {
        // ERC721
        _supportedInterfaces[0x80ac58cd] = true;
    }

    /**
     * @dev Transfers the ownership of an NFT from one address to another address. This function can
     * be changed to payable.
     * @notice Throws unless `msg.sender` is the current owner, an authorized operator, or the
     * approved address for this NFT. Throws if `__from` is not the current owner. Throws if `__to` is
     * the zero address. Throws if `__tokenId` is not a valid NFT. When transfer is complete, this
     * function checks if `__to` is a smart contract (code size > 0). If so, it calls
     * `onERC721Received` on `__to` and throws if the return value is not
     * `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`.
     * @param __from The current owner of the NFT.
     * @param __to The new owner.
     * @param __tokenId The NFT to transfer.
     * @param __data Additional data with no specified format, sent in call to `__to`.
     */
    function safeTransferFrom(
        address __from,
        address __to,
        uint256 __tokenId,
        bytes calldata __data
    )
    external {
        _safeTransferFrom(__from, __to, __tokenId, __data);
    }

    /**
     * @dev Transfers the ownership of an NFT from one address to another address. This function can
     * be changed to payable.
     * @notice This works identically to the other function with an extra data parameter, except this
     * function just sets data to ""
     * @param __from The current owner of the NFT.
     * @param __to The new owner.
     * @param __tokenId The NFT to transfer.
     */
    function safeTransferFrom(
        address __from,
        address __to,
        uint256 __tokenId
    )
    external {
        _safeTransferFrom(__from, __to, __tokenId, "");
    }

    /**
     * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
     * address for this NFT. Throws if `__from` is not the current owner. Throws if `__to` is the zero
     * address. Throws if `__tokenId` is not a valid NFT. This function can be changed to payable.
     * @notice The caller is responsible to confirm that `__to` is capable of receiving NFTs or else
     * they maybe be permanently lost.
     * @param __from The current owner of the NFT.
     * @param __to The new owner.
     * @param __tokenId The NFT to transfer.
     */
    function transferFrom(
        address __from,
        address __to,
        uint256 __tokenId
    )
    external
    canTransfer(__tokenId)
    onlyValidNft(__tokenId) {
        address tokenOwner = _idToOwnerMap[__tokenId];

        require(
            tokenOwner == __from,
            "ERC721::transferFrom: NOT_OWNER"
        );
        require(
            __to != address(0),
            "ERC721::transferFrom: INVALID_RECIPIENT"
        );

        _transfer(__to, __tokenId);
    }

    /**
     * @dev Set or reaffirm the approved address for an NFT. This function can be changed to payable.
     * @notice The zero address indicates there is no approved address. Throws unless `msg.sender` is
     * the current NFT owner, or an authorized operator of the current owner.
     * @param __spender  Address to be approved for the given NFT ID.
     * @param __tokenId  ID of the token to be approved.
     */
    function approve(
        address __spender,
        uint256 __tokenId
    )
    external
    onlyOperator(__tokenId)
    onlyValidNft(__tokenId) {
        address tokenOwner = _idToOwnerMap[__tokenId];
        require(
            __spender != tokenOwner,
            "ERC721::approve: SPENDER_MUST_NOT_BE_OWNER"
        );

        _idToSpenderMap[__tokenId] = __spender;
        emit Approval(tokenOwner, __spender, __tokenId);
    }

    /**
     * @dev Enables or disables approval for a third party ("operator") to manage all of
     * `msg.sender`'s assets. It also emits the ApprovalForAll event.
     * @notice This works even if sender doesn't own any tokens at the time.
     * @param __operator     The address to add to the set of authorized operators.
     * @param _isApproved   True if the operators is approved, false to revoke approval.
     */
    function setApprovalForAll(
        address __operator,
        bool _isApproved
    )
    external {
        _ownerToOperatorToIsApprovedMap[msg.sender][__operator] = _isApproved;
        emit ApprovalForAll(msg.sender, __operator, _isApproved);
    }

    /**
     * @dev Returns the number of NFTs owned by `_owner`. NFTs assigned to the zero address are
     * considered invalid, and this function throws for queries about the zero address.
     * @param _owner Address for whom to query the balance.
     * @return Balance of _owner.
     */
    function balanceOf(
        address __owner
    )
    external
    view
    returns (uint256) {
        require(
            __owner != address(0),
            "ERC721::balanceOf: INVALID_OWNER"
        );
        return _getOwnerTokenCount(__owner);
    }

    function totalSupply() external view returns (uint) {
        return _totalSupply;
    }

    function tokenByIndex(
        uint __index
    )
    external
    view returns (uint) {
        require(
            __index < _totalSupply,
            "ERC721::tokenByIndex: INVALID_INDEX"
        );

        return _allTokens[__index];
    }

    function tokenByIndex(
        uint __index
    )
    external
    view returns (uint) {
        require(
            __index < _totalSupply,
            "ERC721::tokenByIndex: INVALID_INDEX"
        );

        return _allTokens[__index];
    }

    /**
     * @dev Returns the address of the owner of the NFT. NFTs assigned to zero address are considered
     * invalid, and queries about them do throw.
     * @param __tokenId The identifier for an NFT.
     * @return _owner Address of __tokenId owner.
     */
    function ownerOf(
        uint256 __tokenId
    )
    external
    view
    returns (address) {
        address owner = _idToOwnerMap[__tokenId];
        require(
            owner != address(0),
            "ERC721::ownerOf INVALID_TOKEN"
        );
        return owner;
    }

    /**
     * @dev Get the approved address for a single NFT.
     * @notice Throws if `__tokenId` is not a valid NFT.
     * @param __tokenId ID of the NFT to query the approval of.
     * @return Address that __tokenId is approved for.
     */
    function getApproved(
        uint256 __tokenId
    )
    external
    view
    onlyValidNft(__tokenId)
    returns (address) {
        return _idToSpenderMap[__tokenId];
    }

    /**
     * @dev Checks if `__operator` is an approved operator for `_owner`.
     * @param __owner The address that owns the NFTs.
     * @param __operator The address that acts on behalf of the owner.
     * @return True if approved for all, false otherwise.
     */
    function isApprovedForAll(
        address __owner,
        address __operator
    )
    external
    view
    returns (bool) {
        return _ownerToOperatorToIsApprovedMap[_owner][__operator];
    }

    function getAllTokensOf(
        address __owner
    )
    external
    view
    returns (uint[] memory) {
        uint tokenCount = _ownerToTokenCount[__owner];
        uint[] memory tokens = new uint[](tokenCount);
        uint i = 0;
        uint tokenId = _ownerToTokenIds[__owner][LINKED_LIST_GUARD];
        while (tokenId != uint(0)) {
            tokens[i++] = tokenId;
        }
        return tokens;
    }

    // *************************
    // ***** Internal Functions
    // *************************

    /**
     * @dev Actually preforms the transfer.
     * @notice Does NO checks.
     * @param __to Address of a new owner.
     * @param __tokenId The NFT that is being transferred.
     */
    function _transfer(
        address __to,
        uint256 __tokenId
    )
    internal {
        address from = _idToOwnerMap[__tokenId];
        _clearApproval(__tokenId);

        _removeToken(from, __tokenId);
        _addTokenToNewOwner(__to, __tokenId);

        emit Transfer(from, __to, __tokenId);
    }

    /**
     * @dev Mints a new NFT.
     * @notice This is an internal function which should be called from user-implemented external
     * mint function. Its purpose is to show and properly initialize data structures when using this
     * implementation.
     * @param __to The address that will own the minted NFT.
     * @param __tokenId of the NFT to be minted by the msg.sender.
     */
    function _mint(
        address __to,
        uint256 __tokenId
    )
    internal {
        require(
            __to != address(0),
            "ERC721::_mint INVALID_RECIPIENT"
        );
        require(
            _idToOwnerMap[__tokenId] == address(0),
            "ERC721::_mint TOKEN_ALREADY_EXISTS"
        );

        _addTokenToNewOwner(__to, __tokenId);
        emit Transfer(address(0), __to, __tokenId);
    }

    /**
     * @dev Burns a NFT.
     * @notice This is an internal function which should be called from user-implemented external burn
     * function. Its purpose is to show and properly initialize data structures when using this
     * implementation. Also, note that this burn implementation allows the minter to re-mint a burned
     * NFT.
     * @param __tokenId ID of the NFT to be burned.
     */
    function _burn(
        uint256 __tokenId
    )
    internal {
        address tokenOwner = _idToOwnerMap[__tokenId];
        _clearApproval(__tokenId);
        _removeToken(tokenOwner, __tokenId);
        emit Transfer(tokenOwner, address(0), __tokenId);
    }

    /**
     * @dev Removes a NFT from owner.
     * @notice Use and override this function with caution. Wrong usage can have serious consequences.
     * @param __from Address from which we want to remove the NFT.
     * @param __tokenId Which NFT we want to remove.
     */
    function _removeToken(
        address __from,
        uint256 __tokenId
    )
    internal {
        require(
            _idToOwnerMap[__tokenId] == __from,
            "ERC721::_removeToken: NOT_OWNER"
        );

        _ownerToTokenCount[__from] = _ownerToTokenCount[__from] - 1;
        uint previousTokenId = LINKED_LIST_GUARD;
        uint indexedTokenId = _ownerToTokenIds[__from][previousTokenId];

        while (indexedTokenId != uint(0)) {
            if (indexedTokenId == __tokenId) {
                uint nextTokenId = _ownerToTokenIds[__from][__tokenId];
                _ownerToTokenIds[__from][previousTokenId] = nextTokenId;
                delete _ownerToTokenIds[__from][__tokenId];
                break;
            }
            // Proceed to the next element in the linked list
            previousTokenId = indexedTokenId;
            indexedTokenId = _ownerToTokenIds[__from][indexedTokenId];
        }

        delete _idToOwnerMap[__tokenId];
    }

    /**
     * @dev Assigns a new NFT to owner.
     * @notice Use and override this function with caution. Wrong usage can have serious consequences.
     * @param __to Address to which we want to add the NFT.
     * @param __tokenId Which NFT we want to add.
     */
    function _addTokenToNewOwner(
        address __to,
        uint256 __tokenId
    )
    internal {
        require(
            _idToOwnerMap[__tokenId] == address(0),
            "ERC721::_addTokenToNewOwner TOKEN_ALREADY_EXISTS"
        );

        _idToOwnerMap[__tokenId] = __to;
        _ownerToTokenCount[__to] = _ownerToTokenCount[__to] + 1;

        /// Append the token to the end of the linked list of the owner.
        uint previousIndex = LINKED_LIST_GUARD;
        uint indexedTokenId = _ownerToTokenIds[__to][previousIndex];

        while (indexedTokenId != uint(0)) {
            previousIndex = indexedTokenId;
            indexedTokenId = _ownerToTokenIds[__to][indexedTokenId];
        }
        _ownerToTokenIds[__to][previousIndex] = __tokenId;

    }

    /**
     * @dev Helper function that gets NFT count of owner. This is needed for overriding in enumerable
     * extension to remove double storage (gas optimization) of owner nft count.
     * @param __owner Address for whom to query the count.
     * @return Number of _owner NFTs.
     */
    function _getOwnerTokenCount(
        address __owner
    )
    internal
    view
    returns (uint256) {
        return _ownerToTokenCount[__owner];
    }

    /**
     * @dev Actually perform the safeTransferFrom.
     * @param __from The current owner of the NFT.
     * @param __to The new owner.
     * @param __tokenId The NFT to transfer.
     * @param __data Additional data with no specified format, sent in call to `__to`.
     */
    function _safeTransferFrom(
        address __from,
        address __to,
        uint256 __tokenId,
        bytes memory __data
    )
    internal
    canTransfer(__tokenId)
    onlyValidNft(__tokenId) {
        address tokenOwner = _idToOwnerMap[__tokenId];
        require(
            tokenOwner == __from,
            "ERC721::_safeTransferFrom NOT_OWNER"
        );
        require(
            __to != address(0),
            "ERC721::_safeTransferFrom INVALID_RECIPIENT"
        );

        _transfer(__to, __tokenId);

        if (__to.isContract()) {
            bytes4 retval = IERC721TokenReceiver(__to).onERC721Received(msg.sender, __from, __tokenId, __data);
            require(
                retval == MAGIC_ON_ERC721_RECEIVED,
                "ERC721::_safeTransferFrom: UNABLE_TO_RECEIVE_TOKEN"
            );
        }
    }

    /**
     * @dev Clears the current approval of a given NFT ID.
     * @param __tokenId ID of the NFT to be transferred.
     */
    function _clearApproval(
        uint256 __tokenId
    )
    internal {
        if (_idToSpenderMap[__tokenId] != address(0)) {
            delete _idToSpenderMap[__tokenId];
        }
    }

}