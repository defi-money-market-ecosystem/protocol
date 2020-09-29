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
import "../interfaces/IERC721TokenReceiver.sol";

import "../AssetIntroducerData.sol";

/**
 * @dev Implementation of ERC-721 non-fungible token standard.
 */
contract ERC721Token is IERC721, AssetIntroducerData {

    using SafeMath for uint256;
    using OpenZeppelinUpgradesAddress for address;

    /**
     * @dev Magic value of a smart contract that can recieve NFT.
     * Equal to: bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")).
     */
    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    /**
     * @dev Guarantees that the msg.sender is an owner or operator of the given NFT.
     * @param _tokenId ID of the NFT to validate.
     */
    modifier onlyOperator(uint256 _tokenId) {
        address tokenOwner = _idToOwner[_tokenId];
        require(
            tokenOwner == msg.sender || _ownerToOperators[tokenOwner][msg.sender],
            "ERC721: NOT_OWNER_OR_NOT_OPERATOR"
        );
        _;
    }

    /**
     * @dev Guarantees that the msg.sender is allowed to transfer NFT.
     * @param _tokenId ID of the NFT to transfer.
     */
    modifier canTransfer(uint256 _tokenId) {
        address tokenOwner = _idToOwner[_tokenId];
        require(
            tokenOwner == msg.sender ||
            _idToApproval[_tokenId] == msg.sender ||
            _ownerToOperators[tokenOwner][msg.sender],
            "ERC721: NOT_APPROVED_OR_NOT_OPERATOR"
        );

        _;
    }

    /**
     * @dev Guarantees that _tokenId is a valid Token.
     * @param _tokenId ID of the NFT to validate.
     */
    modifier onlyValidToken(uint256 _tokenId) {
        require(
            _idToOwner[_tokenId] != address(0),
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
     * approved address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is
     * the zero address. Throws if `_tokenId` is not a valid NFT. When transfer is complete, this
     * function checks if `_to` is a smart contract (code size > 0). If so, it calls
     * `onERC721Received` on `_to` and throws if the return value is not
     * `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     * @param _data Additional data with no specified format, sent in call to `_to`.
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes calldata _data
    )
    external {
        _safeTransferFrom(_from, _to, _tokenId, _data);
    }

    /**
     * @dev Transfers the ownership of an NFT from one address to another address. This function can
     * be changed to payable.
     * @notice This works identically to the other function with an extra data parameter, except this
     * function just sets data to ""
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
    external {
        _safeTransferFrom(_from, _to, _tokenId, "");
    }

    /**
     * @dev Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
     * address for this NFT. Throws if `_from` is not the current owner. Throws if `_to` is the zero
     * address. Throws if `_tokenId` is not a valid NFT. This function can be changed to payable.
     * @notice The caller is responsible to confirm that `_to` is capable of receiving NFTs or else
     * they maybe be permanently lost.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    )
    external
    canTransfer(_tokenId)
    onlyValidToken(_tokenId) {
        address tokenOwner = _idToOwner[_tokenId];

        require(
            tokenOwner == _from,
            "ERC721::transferFrom: NOT_OWNER"
        );
        require(
            _to != address(0),
            "ERC721::transferFrom: INVALID_RECIPIENT"
        );

        _transfer(_to, _tokenId);
    }

    /**
     * @dev Set or reaffirm the approved address for an NFT. This function can be changed to payable.
     * @notice The zero address indicates there is no approved address. Throws unless `msg.sender` is
     * the current NFT owner, or an authorized operator of the current owner.
     * @param _spender  Address to be approved for the given NFT ID.
     * @param _tokenId  ID of the token to be approved.
     */
    function approve(
        address _spender,
        uint256 _tokenId
    )
    external
    onlyOperator(_tokenId)
    onlyValidToken(_tokenId) {
        address tokenOwner = _idToOwner[_tokenId];
        require(
            _spender != tokenOwner,
        //                IS_OWNER
            "ERC721::approve: SPENDER_MUST_NOT_BE_OWNER"
        );

        _idToApproval[_tokenId] = _spender;
        emit Approval(tokenOwner, _spender, _tokenId);
    }

    /**
     * @dev Enables or disables approval for a third party ("operator") to manage all of
     * `msg.sender`'s assets. It also emits the ApprovalForAll event.
     * @notice This works even if sender doesn't own any tokens at the time.
     * @param _operator     The address to add to the set of authorized operators.
     * @param _isApproved   True if the operators is approved, false to revoke approval.
     */
    function setApprovalForAll(
        address _operator,
        bool _isApproved
    )
    external {
        _ownerToOperators[msg.sender][_operator] = _isApproved;
        emit ApprovalForAll(msg.sender, _operator, _isApproved);
    }

    /**
     * @dev Returns the number of NFTs owned by `_owner`. NFTs assigned to the zero address are
     * considered invalid, and this function throws for queries about the zero address.
     * @param _owner Address for whom to query the balance.
     * @return Balance of _owner.
     */
    function balanceOf(
        address _owner
    )
    external
    view
    returns (uint256){
        require(
            _owner != address(0),
            "ERC721::balanceOf: INVALID_OWNER"
        );
        return _getOwnerTokenCount(_owner);
    }

    /**
     * @dev Returns the address of the owner of the NFT. NFTs assigned to zero address are considered
     * invalid, and queries about them do throw.
     * @param _tokenId The identifier for an NFT.
     * @return _owner Address of _tokenId owner.
     */
    function ownerOf(
        uint256 _tokenId
    )
    external
    view
    returns (address) {
        address owner = _idToOwner[_tokenId];
        require(
            owner != address(0),
            "ERC721::ownerOf INVALID_TOKEN"
        );
        return owner;
    }

    /**
     * @dev Get the approved address for a single NFT.
     * @notice Throws if `_tokenId` is not a valid NFT.
     * @param _tokenId ID of the NFT to query the approval of.
     * @return Address that _tokenId is approved for.
     */
    function getApproved(
        uint256 _tokenId
    )
    external
    view
    onlyValidToken(_tokenId)
    returns (address) {
        return _idToApproval[_tokenId];
    }

    /**
     * @dev Checks if `_operator` is an approved operator for `_owner`.
     * @param _owner The address that owns the NFTs.
     * @param _operator The address that acts on behalf of the owner.
     * @return True if approved for all, false otherwise.
     */
    function isApprovedForAll(
        address _owner,
        address _operator
    )
    external
    view
    returns (bool) {
        return _ownerToOperators[_owner][_operator];
    }

    /**
     * @dev Actually preforms the transfer.
     * @notice Does NO checks.
     * @param _to Address of a new owner.
     * @param _tokenId The NFT that is being transferred.
     */
    function _transfer(
        address _to,
        uint256 _tokenId
    )
    internal {
        address from = _idToOwner[_tokenId];
        _clearApproval(_tokenId);

        _removeToken(from, _tokenId);
        _addTokenToNewOwner(_to, _tokenId);

        emit Transfer(from, _to, _tokenId);
    }

    /**
     * @dev Mints a new NFT.
     * @notice This is an internal function which should be called from user-implemented external
     * mint function. Its purpose is to show and properly initialize data structures when using this
     * implementation.
     * @param _to The address that will own the minted NFT.
     * @param _tokenId of the NFT to be minted by the msg.sender.
     */
    function _mint(
        address _to,
        uint256 _tokenId
    )
    internal {
        require(
            _to != address(0),
            "ERC721::_mint INVALID_RECIPIENT"
        );
        require(
            _idToOwner[_tokenId] == address(0),
            "ERC721::_mint TOKEN_ALREADY_EXISTS"
        );

        _addTokenToNewOwner(_to, _tokenId);
        emit Transfer(address(0), _to, _tokenId);
    }

    /**
     * @dev Burns a NFT.
     * @notice This is an internal function which should be called from user-implemented external burn
     * function. Its purpose is to show and properly initialize data structures when using this
     * implementation. Also, note that this burn implementation allows the minter to re-mint a burned
     * NFT.
     * @param _tokenId ID of the NFT to be burned.
     */
    function _burn(
        uint256 _tokenId
    )
    internal
    onlyValidToken(_tokenId) {
        address tokenOwner = _idToOwner[_tokenId];
        _clearApproval(_tokenId);
        _removeToken(tokenOwner, _tokenId);
        emit Transfer(tokenOwner, address(0), _tokenId);
    }

    /**
     * @dev Removes a NFT from owner.
     * @notice Use and override this function with caution. Wrong usage can have serious consequences.
     * @param _from Address from wich we want to remove the NFT.
     * @param _tokenId Which NFT we want to remove.
     */
    function _removeToken(
        address _from,
        uint256 _tokenId
    )
    internal {
        require(
            _idToOwner[_tokenId] == _from,
            "ERC721::_removeToken: NOT_OWNER"
        );

        _ownerToTokenCount[_from] = _ownerToTokenCount[_from] - 1;
        delete _idToOwner[_tokenId];
    }

    /**
     * @dev Assigns a new NFT to owner.
     * @notice Use and override this function with caution. Wrong usage can have serious consequences.
     * @param _to Address to which we want to add the NFT.
     * @param _tokenId Which NFT we want to add.
     */
    function _addTokenToNewOwner(
        address _to,
        uint256 _tokenId
    )
    internal {
        require(
            _idToOwner[_tokenId] == address(0),
            "ERC721::_addTokenToNewOwner TOKEN_ALREADY_EXISTS"
        );

        _idToOwner[_tokenId] = _to;
        _ownerToTokenCount[_to] = _ownerToTokenCount[_to].add(1);
    }

    /**
     * @dev Helper function that gets NFT count of owner. This is needed for overriding in enumerable
     * extension to remove double storage (gas optimization) of owner nft count.
     * @param _owner Address for whom to query the count.
     * @return Number of _owner NFTs.
     */
    function _getOwnerTokenCount(
        address _owner
    )
    internal
    view
    returns (uint256) {
        return _ownerToTokenCount[_owner];
    }

    /**
     * @dev Actually perform the safeTransferFrom.
     * @param _from The current owner of the NFT.
     * @param _to The new owner.
     * @param _tokenId The NFT to transfer.
     * @param _data Additional data with no specified format, sent in call to `_to`.
     */
    function _safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory _data
    )
    internal
    canTransfer(_tokenId)
    onlyValidToken(_tokenId) {
        address tokenOwner = _idToOwner[_tokenId];
        require(
            tokenOwner == _from,
            "ERC721::_safeTransferFrom NOT_OWNER"
        );
        require(
            _to != address(0),
            "ERC721::_safeTransferFrom INVALID_RECIPIENT"
        );

        _transfer(_to, _tokenId);

        if (_to.isContract()) {
            bytes4 retval = IERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
            require(
                retval == MAGIC_ON_ERC721_RECEIVED,
                "ERC721::_safeTransferFrom: UNABLE_TO_RECEIVE_TOKEN"
            );
        }
    }

    /**
     * @dev Clears the current approval of a given NFT ID.
     * @param _tokenId ID of the NFT to be transferred.
     */
    function _clearApproval(
        uint256 _tokenId
    )
    internal {
        if (_idToApproval[_tokenId] != address(0)) {
            delete _idToApproval[_tokenId];
        }
    }

}