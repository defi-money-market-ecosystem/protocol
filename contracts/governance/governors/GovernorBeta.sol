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

import "./GovernorAlpha.sol";
import "../dmg/SafeBitMath.sol";

import "../../external/asset_introducers/v1/IAssetIntroducerV1.sol";

contract GovernorBeta is GovernorAlpha {

    using SafeBitMath for uint128;

    event LocalOperatorSet(address indexed voter, address indexed operator, bool isTrusted);
    event GlobalOperatorSet(address indexed operator, bool isTrusted);

    modifier onlyTrustedOperator(address voter) {
        require(
            _globalOperatorToIsSupportedMap[msg.sender] ||
            _voterToLocalOperatorToIsSupportedMap[voter][msg.sender] ||
            msg.sender == voter,
            "GovernorBeta: UNAUTHORIZED_OPERATOR"
        );

        _;
    }

    /// A wrapped variant of DMG for when the user stakes DMG in an official contract and still needs access to their
    /// ballots
    IDMGToken public wDmg;
    IAssetIntroducerV1 public assetIntroducerProxy;
    mapping(address => mapping(address => bool)) internal _voterToLocalOperatorToIsSupportedMap;
    mapping(address => bool) internal _globalOperatorToIsSupportedMap;

    constructor(
        address __wDmg,
        address __dmg,
        address __guardian
    ) public GovernorAlpha(__dmg, __guardian) {
        wDmg = IDMGToken(__wDmg);
    }

    // *************************
    // ***** Admin Functions
    // *************************

    function setGlobalOperator(
        address __operator,
        bool __isTrusted
    ) public {
        require(
            address(timelock) == msg.sender || guardian == msg.sender,
            "GovernorBeta::setGlobalOperator: UNAUTHORIZED"
        );

        _globalOperatorToIsSupportedMap[__operator] = __isTrusted;
        emit GlobalOperatorSet(__operator, __isTrusted);
    }

    // *************************
    // ***** User Functions
    // *************************

    function setLocalOperator(
        address __operator,
        bool __isTrusted
    ) public {
        _voterToLocalOperatorToIsSupportedMap[msg.sender][__operator] = __isTrusted;
        emit LocalOperatorSet(msg.sender, __operator, __isTrusted);
    }

    /**
     * Can be called by a global operator or local operator on behalf of `voter` to cast votes on `voter`'s behalf.
     *
     * This function is mainly used to wrap around voting functionality with a proxy contract to perform additional
     * logic before or after voting.
     *
     * @return The amount of votes the user casted in favor of or against the proposal.
     */
    function castVote(
        address __voter,
        uint __proposalId,
        bool __support
    )
    onlyTrustedOperator(__voter)
    public returns (uint128) {
        return _castVote(__voter, __proposalId, __support);
    }

    // *************************
    // ***** Misc Functions
    // *************************

    function getIsLocalOperator(
        address __voter,
        address __operator
    )
    public view returns (bool) {
        return _voterToLocalOperatorToIsSupportedMap[__voter][__operator];
    }

    function getIsGlobalOperator(
        address __operator
    )
    public view returns (bool) {
        return _globalOperatorToIsSupportedMap[__operator];
    }

    // *************************
    // ***** Internal Functions
    // *************************

    function _getVotes(
        address __user,
        uint __blockNumber
    ) internal view returns (uint128) {
        uint128 dmgVotes = SafeBitMath.add128(
            dmg.getPriorVotes(__user, __blockNumber),
            wDmg.getPriorVotes(__user, __blockNumber)
        );

        return SafeBitMath.add128(
            dmgVotes,
            assetIntroducerProxy.getPriorVotes(__user, __blockNumber)
        );
    }

}