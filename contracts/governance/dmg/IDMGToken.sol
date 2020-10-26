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
pragma experimental ABIEncoderV2;

interface IDMGToken {

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint64 fromBlock;
        uint128 votes;
    }

    /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    // *************************
    // ***** Functions
    // *************************

    function getPriorVotes(address account, uint blockNumber) external view returns (uint128);

    function getCurrentVotes(address account) external view returns (uint128);

    function delegates(address delegator) external view returns (address);

    function burn(uint amount) external returns (bool);

    function approveBySig(
        address spender,
        uint rawAmount,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

}