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


pragma solidity >=0.5.0;

/**
 * @dev Optional enumeration extension for ERC-721 non-fungible token standard.
 * See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md.
 */
interface ERC721Enumerable {

    /**
     * @dev Returns a count of valid NFTs tracked by this contract, where each one of them has an
     * assigned and queryable owner not equal to the zero address.
     * @return Total supply of NFTs.
     */
    function totalSupply()
    external
    view
    returns (uint256);

    /**
     * @dev Returns the token identifier for the `_index`th NFT. Sort order is not specified.
     * @param _index A counter less than `totalSupply()`.
     * @return Token id.
     */
    function tokenByIndex(
        uint256 _index
    )
    external
    view
    returns (uint256);

    /**
     * @dev Returns the token identifier for the `_index`th NFT assigned to `_owner`. Sort order is
     * not specified. It throws if `_index` >= `balanceOf(_owner)` or if `_owner` is the zero address,
     * representing invalid NFTs.
     * @param _owner An address where we are interested in NFTs owned by them.
     * @param _index A counter less than `balanceOf(_owner)`.
     * @return Token id.
     */
    function tokenOfOwnerByIndex(
        address _owner,
        uint256 _index
    )
    external
    view
    returns (uint256);

}