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

contract GovernorBeta is GovernorAlpha {

    using SafeBitMath for uint128;

    event LocalOperatorSet(address indexed voter, address indexed operator, bool isTrusted);
    event GlobalOperatorSet(address indexed operator, bool isTrusted);

    modifier onlyTrustedOperator(address voter) {
        require(
            _globalOperatorToIsSupportedMap[msg.sender] || _voterToLocalOperatorToIsSupportedMap[voter][msg.sender],
            "GovernorBeta: UNAUTHORIZED"
        );

        _;
    }

    IDMGToken public wDmg;
    mapping(address => mapping(address => bool)) internal _voterToLocalOperatorToIsSupportedMap;
    mapping(address => bool) internal _globalOperatorToIsSupportedMap;

    constructor(
        address wDmg_,
        address dmg_,
        address guardian_
    ) public GovernorAlpha(dmg_, guardian_) {
        wDmg = IDMGToken(wDmg_);
    }

    function setLocalOperator(
        address operator,
        bool isTrusted
    ) public {
        _voterToLocalOperatorToIsSupportedMap[msg.sender][operator] = isTrusted;
        emit LocalOperatorSet(msg.sender, operator, isTrusted);
    }

    function setGlobalOperator(
        address operator,
        bool isTrusted
    ) public {
        require(
            address(timelock) == msg.sender,
            "GovernorBeta::setGlobalOperator: UNAUTHORIZED"
        );

        _globalOperatorToIsSupportedMap[operator] = isTrusted;
        emit GlobalOperatorSet(operator, isTrusted);
    }

    function getIsLocalOperator(
        address voter,
        address operator
    )
    public returns (bool) {
        return _voterToLocalOperatorToIsSupportedMap[voter][operator];
    }

    function getIsGlobalOperator(
        address operator
    )
    public returns (bool) {
        return _globalOperatorToIsSupportedMap[operator];
    }

    /**
     * Can be called by a global operator or local operator on behalf of `voter` to cast votes on `voter`'s behalf.
     *
     * This function is mainly used to wrap around voting functionality with a proxy contract to perform additional
     * logic before or after voting.
     */
    function castVote(
        address voter,
        uint proposalId,
        bool support
    )
    onlyTrustedOperator(voter)
    public {
        return _castVote(voter, proposalId, support);
    }

    function _getVotes(
        address user,
        uint blockNumber
    ) internal view returns (uint128) {
        return SafeBitMath.add128(
            dmg.getPriorVotes(user, blockNumber),
            wDmg.getPriorVotes(user, blockNumber)
        );
    }

}