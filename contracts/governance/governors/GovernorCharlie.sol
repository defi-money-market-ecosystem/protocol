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

import "./GovernorBeta.sol";

contract GovernorCharlie is GovernorBeta {

    /// A wrapped variant of DMG for when the user stakes DMG in an official contract and still needs access to their
    /// ballots
    IDMGToken public sDmg;

    constructor(
        address __sDmg,
        address __assetIntroducerProxy,
        address __dmg,
        address __guardian
    ) public GovernorBeta(__assetIntroducerProxy, __dmg, __guardian) {
        sDmg = IDMGToken(__sDmg);
    }

    function getCurrentVotes(
        address __user
    ) external view returns (uint) {
        return _getVotes(__user, block.number - 1);
    }

    function getPriorVotes(
        address __user,
        uint __blockNumber
    ) external view returns (uint) {
        return _getVotes(__user, __blockNumber);
    }

    // *************************
    // ***** Internal Functions
    // *************************

    function _getVotes(
        address __user,
        uint __blockNumber
    ) internal view returns (uint128) {
        return SafeBitMath.add128(
            super._getVotes(__user, __blockNumber),
            sDmg.getPriorVotes(__user, __blockNumber)
        );
    }

}