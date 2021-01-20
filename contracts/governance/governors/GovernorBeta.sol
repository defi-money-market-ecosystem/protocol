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
            msg.sender == voter ||
            _globalOperatorToIsSupportedMap[msg.sender] ||
            _voterToLocalOperatorToIsSupportedMap[voter][msg.sender],
            "GovernorBeta: UNAUTHORIZED_OPERATOR"
        );

        _;
    }

    IAssetIntroducerV1 public assetIntroducerProxy;
    mapping(address => mapping(address => bool)) internal _voterToLocalOperatorToIsSupportedMap;
    mapping(address => bool) internal _globalOperatorToIsSupportedMap;

    constructor(
        address __assetIntroducerProxy,
        address __dmg,
        address __guardian
    ) public GovernorAlpha(__dmg, __guardian) {
        assetIntroducerProxy = IAssetIntroducerV1(__assetIntroducerProxy);
    }

    // *************************
    // ***** Admin Functions
    // *************************

    function setGlobalOperator(
        address __operator,
        bool __isTrusted
    ) public {
        require(
            address(timelock) == msg.sender,
            "GovernorBeta::setGlobalOperator: UNAUTHORIZED"
        );

        _globalOperatorToIsSupportedMap[__operator] = __isTrusted;
        emit GlobalOperatorSet(__operator, __isTrusted);
    }

    function __acceptAdmin() public {
        require(
            msg.sender == address(timelock),
            "GovernorBeta::__acceptAdmin: sender must be timelock"
        );

        timelock.acceptAdmin();
    }

    function __queueSetTimelockPendingAdmin(
        address,
        uint
    ) public {
        // The equivalent of this function should be called via governance proposal execution
        revert("GovernorBeta::__queueSetTimelockPendingAdmin: NOT_USED");
    }

    function __executeSetTimelockPendingAdmin(
        address,
        uint
    ) public {
        // The equivalent of this function should be called via governance proposal execution
        revert("GovernorBeta::__executeSetTimelockPendingAdmin: NOT_USED");
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
    ) public view returns (bool) {
        return _voterToLocalOperatorToIsSupportedMap[__voter][__operator];
    }

    function getIsGlobalOperator(
        address __operator
    ) public view returns (bool) {
        return _globalOperatorToIsSupportedMap[__operator];
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
            assetIntroducerProxy.getPriorVotes(__user, __blockNumber)
        );
    }

}