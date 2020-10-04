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

import "../../../node_modules/@openzeppelin/upgrades/contracts/Initializable.sol";

import "./IDMGToken.sol";

contract WrappedDmgTokenData is Initializable {

    // *************************
    // ***** State Variables
    // *************************

    uint public totalSupply;

    /// @notice Allowance amounts on behalf of others
    mapping(address => mapping(address => uint128)) internal allowances;

    /// @notice Official record of token balances for each account
    mapping(address => uint128) internal balances;

    /// @notice A record of each account's delegate
    mapping(address => address) public delegates;

    /// @notice A record of votes checkpoints for each account, by index
    mapping(address => mapping(uint64 => IDMGToken.Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping(address => uint64) public numCheckpoints;

    bytes32 public domainSeparator;

    /// @notice A record of states for signing / validating signatures
    mapping(address => uint) public nonces;

    mapping(address => bool) internal _minterMap;

    IDMGToken public dmg;

    address public owner;

    // *************************
    // ***** Modifiers
    // *************************

    modifier onlyOwner {
        require(msg.sender == owner, "WrappedDmgTokenData: UNAUTHORIZED");
        _;
    }

}