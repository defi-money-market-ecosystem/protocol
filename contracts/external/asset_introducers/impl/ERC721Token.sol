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
import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/IERC721.sol";
import "../interfaces/IERC721Enumerable.sol";
import "../interfaces/IERC721Metadata.sol";
import "../interfaces/IERC721TokenReceiver.sol";

import "../AssetIntroducerData.sol";

import "./ERC721TokenLib.sol";

/**
 * @dev Implementation of ERC-721 non-fungible token standard.
 */
contract ERC721Token is IERC721, IERC721Metadata, IERC721Enumerable, AssetIntroducerData {

    using ERC721TokenLib for ERC721StateV1;
    using SafeMath for uint256;

    // *************************
    // ***** Modifiers
    // *************************

    /**
     * @dev Guarantees that the msg.sender is an owner or operator of the given NFT.
     * @param __tokenId ID of the NFT to validate.
     */
    modifier requireIsOperator(uint256 __tokenId) {
        address tokenOwner = _erc721StateV1.idToOwnerMap[__tokenId];
        require(
            tokenOwner == msg.sender || _erc721StateV1.ownerToOperatorToIsApprovedMap[tokenOwner][msg.sender],
            "ERC721Token: NOT_OWNER_OR_NOT_OPERATOR"
        );

        _;
    }

    /**
     * @dev Guarantees that the msg.sender is allowed to transfer NFT.
     * @param __tokenId ID of the NFT to transfer.
     */
    modifier requireCanTransfer(uint256 __tokenId) {
        address tokenOwner = _erc721StateV1.idToOwnerMap[__tokenId];
        require(
            tokenOwner == msg.sender ||
            _erc721StateV1.idToSpenderMap[__tokenId] == msg.sender ||
            _erc721StateV1.ownerToOperatorToIsApprovedMap[tokenOwner][msg.sender],
            "ERC721Token: NOT_OWNER_OR_NOT_APPROVED_OR_NOT_OPERATOR"
        );

        _;
    }

    // *************************
    // ***** Functions
    // *************************

    /**
     * @dev Contract constructor.
     */
    function initialize(
        string memory __baseURI
    )
    public
    initializer {
        _guardCounter = 1;
        _erc721StateV1.initialize(__baseURI);
    }

    /// @notice Query if a contract implements an interface
    /// @param __interfaceId The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(
        bytes4 __interfaceId
    ) external view returns (bool) {
        return _erc721StateV1.supportsInterface(__interfaceId);
    }

    function baseURI() external view returns (string memory) {
        return _erc721StateV1.baseURI;
    }

    function setBaseURI(
        string calldata __baseURI
    )
    onlyOwnerOrGuardian
    nonReentrant
    external {
        _erc721StateV1.setBaseURI(__baseURI);
    }

    function tokenURI(
        uint256 __tokenId
    )
    requireIsValidNft(__tokenId)
    external view returns (string memory) {
        return _erc721StateV1.tokenURI(__tokenId);
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
    external
    nonReentrant
    requireCanTransfer(__tokenId)
    requireIsValidNft(__tokenId) {
        AssetIntroducer memory assetIntroducer = _assetIntroducerStateV1.idToAssetIntroducer[__tokenId];
        _erc721StateV1.safeTransferFrom(
            _voteStateV1,
            __from,
            __to,
            __tokenId,
            __data,
            assetIntroducer
        );
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
    external
    nonReentrant
    requireCanTransfer(__tokenId)
    requireIsValidNft(__tokenId) {
        _erc721StateV1.safeTransferFrom(
            _voteStateV1,
            __from,
            __to,
            __tokenId,
            "",
            _assetIntroducerStateV1.idToAssetIntroducer[__tokenId]
        );
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
    nonReentrant
    requireCanTransfer(__tokenId)
    requireIsValidNft(__tokenId) {
        _erc721StateV1.transferFrom(
            _voteStateV1,
            __from,
            __to,
            __tokenId,
            _assetIntroducerStateV1.idToAssetIntroducer[__tokenId]
        );
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
    nonReentrant
    requireIsOperator(__tokenId)
    requireIsValidNft(__tokenId) {
        _erc721StateV1.approve(__spender, __tokenId);
    }

    /**
     * @dev Enables or disables approval for a third party ("operator") to manage all of
     * `msg.sender`'s assets. It also emits the ApprovalForAll event.
     * @notice This works even if sender doesn't own any tokens at the time.
     * @param __operator    The address to add to the set of authorized operators.
     * @param __isApproved  True if the operators is approved, false to revoke approval.
     */
    function setApprovalForAll(
        address __operator,
        bool __isApproved
    )
    external
    nonReentrant {
        _erc721StateV1.setApprovalForAll(__operator, __isApproved);
    }

    /**
     * @dev Returns the number of NFTs owned by `__owner`. NFTs assigned to the zero address are
     * considered invalid, and this function throws for queries about the zero address.
     * @param __owner Address for whom to query the balance.
     * @return Balance of _owner.
     */
    function balanceOf(
        address __owner
    )
    public view returns (uint) {
        return _erc721StateV1.balanceOf(__owner);
    }

    function totalSupply() external view returns (uint) {
        return _erc721StateV1.totalSupply;
    }

    function tokenByIndex(
        uint __index
    )
    external
    view returns (uint) {
        return _erc721StateV1.tokenByIndex(__index);
    }

    function tokenOfOwnerByIndex(
        address __owner,
        uint __index
    )
    external
    view returns (uint) {
        return _erc721StateV1.tokenOfOwnerByIndex(__owner, __index);
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
    external view returns (address) {
        return _erc721StateV1.ownerOf(__tokenId);
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
    requireIsValidNft(__tokenId)
    external view returns (address) {
        return _erc721StateV1.getApproved(__tokenId);
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
    external view returns (bool) {
        return _erc721StateV1.isApprovedForAll(__owner, __operator);
    }

    function getAllTokensOf(
        address __owner
    )
    external view returns (uint[] memory) {
        return _erc721StateV1.getAllTokensOf(__owner);
    }

    // *************************
    // ***** Internal Functions
    // *************************

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
        _erc721StateV1.mint(__to, __tokenId);
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
        _erc721StateV1.burn(__tokenId);
    }

}