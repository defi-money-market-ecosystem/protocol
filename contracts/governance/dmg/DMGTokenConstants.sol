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


pragma solidity ^0.5.13;

contract DMGTokenConstants {

    string public constant symbol = "DMG";

    uint8 public constant decimals = 18;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPE_HASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPE_HASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice The EIP-712 typehash for the transfer struct used by the contract
    bytes32 public constant TRANSFER_TYPE_HASH = keccak256("Transfer(address recipient,uint256 rawAmount,uint256 nonce,uint256 expiry)");

    /// @notice The EIP-712 typehash for the approve struct used by the contract
    bytes32 public constant APPROVE_TYPE_HASH = keccak256("Approve(address spender,uint256 rawAmount,uint256 nonce,uint256 expiry)");

}