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

import "../../../governance/dmg/SafeBitMath.sol";

import "../AssetIntroducerData.sol";

library AssetIntroducerVotingLib {

    // *************************
    // ***** Events
    // *************************

    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    // *************************
    // ***** Functions
    // *************************

    function getCurrentVotes(
        AssetIntroducerData.VoteStateV1 storage __state,
        address __owner
    ) public view returns (uint) {
        uint64 checkpointCount = __state.ownerToCheckpointCountMap[__owner];
        return checkpointCount > 0 ? __state.ownerToCheckpointIndexToCheckpointMap[__owner][checkpointCount - 1].votes : 0;
    }

    function getPriorVotes(
        AssetIntroducerData.VoteStateV1 storage __state,
        address __owner,
        uint __blockNumber
    ) public view returns (uint128) {
        require(
            __blockNumber < block.number,
            "AssetIntroducerVotingLib::getPriorVotes: not yet determined"
        );

        uint64 checkpointCount = __state.ownerToCheckpointCountMap[__owner];
        if (checkpointCount == 0) {
            return 0;
        }

        // First check most recent balance
        if (__state.ownerToCheckpointIndexToCheckpointMap[__owner][checkpointCount - 1].fromBlock <= __blockNumber) {
            return __state.ownerToCheckpointIndexToCheckpointMap[__owner][checkpointCount - 1].votes;
        }

        // Next check implicit zero balance
        if (__state.ownerToCheckpointIndexToCheckpointMap[__owner][0].fromBlock > __blockNumber) {
            return 0;
        }

        uint64 lower = 0;
        uint64 upper = checkpointCount - 1;
        while (upper > lower) {
            // ceil, avoiding overflow
            uint64 center = upper - (upper - lower) / 2;
            AssetIntroducerData.Checkpoint memory checkpoint = __state.ownerToCheckpointIndexToCheckpointMap[__owner][center];
            if (checkpoint.fromBlock == __blockNumber) {
                return checkpoint.votes;
            } else if (checkpoint.fromBlock < __blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return __state.ownerToCheckpointIndexToCheckpointMap[__owner][lower].votes;
    }

    function moveDelegates(
        AssetIntroducerData.VoteStateV1 storage __state,
        address __fromOwner,
        address __toOwner,
        uint128 __amount
    ) public {
        if (__fromOwner != __toOwner && __amount > 0) {
            if (__fromOwner != address(0)) {
                uint64 fromCheckpointCount = __state.ownerToCheckpointCountMap[__fromOwner];
                uint128 fromVotesOld = fromCheckpointCount > 0 ? __state.ownerToCheckpointIndexToCheckpointMap[__fromOwner][fromCheckpointCount - 1].votes : 0;
                uint128 fromVotesNew = SafeBitMath.sub128(
                    fromVotesOld,
                    __amount,
                    "AssetIntroducerVotingLib::moveDelegates: VOTE_UNDERFLOW"
                );
                _writeCheckpoint(__state, __fromOwner, fromCheckpointCount, fromVotesOld, fromVotesNew);
            }

            if (__toOwner != address(0)) {
                uint64 toCheckpointCount = __state.ownerToCheckpointCountMap[__toOwner];
                uint128 toVotesOld = toCheckpointCount > 0 ? __state.ownerToCheckpointIndexToCheckpointMap[__toOwner][toCheckpointCount - 1].votes : 0;
                uint128 toVotesNew = SafeBitMath.add128(
                    toVotesOld,
                    __amount,
                    "AssetIntroducerVotingLib::moveDelegates: VOTE_OVERFLOW"
                );
                _writeCheckpoint(__state, __toOwner, toCheckpointCount, toVotesOld, toVotesNew);
            }
        }
    }


    function _writeCheckpoint(
        AssetIntroducerData.VoteStateV1 storage __state,
        address __owner,
        uint64 __checkpointCount,
        uint128 __oldVotes,
        uint128 __newVotes
    ) internal {
        uint64 blockNumber = SafeBitMath.safe64(
            block.number,
            "AssetIntroducerVotingLib::_writeCheckpoint: INVALID_BLOCK_NUMBER"
        );

        if (__checkpointCount > 0 && __state.ownerToCheckpointIndexToCheckpointMap[__owner][__checkpointCount - 1].fromBlock == blockNumber) {
            __state.ownerToCheckpointIndexToCheckpointMap[__owner][__checkpointCount - 1].votes = __newVotes;
        } else {
            __state.ownerToCheckpointIndexToCheckpointMap[__owner][__checkpointCount] = AssetIntroducerData.Checkpoint(blockNumber, __newVotes);
            __state.ownerToCheckpointCountMap[__owner] = __checkpointCount + 1;
        }

        emit DelegateVotesChanged(__owner, __oldVotes, __newVotes);
    }

}