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
pragma experimental ABIEncoderV2;

import "../../../node_modules/@openzeppelin/upgrades/contracts/Initializable.sol";

import "../../protocol/interfaces/IOwnableOrGuardian.sol";

contract AssetIntroducerStakingData is IOwnableOrGuardian {

    /// For preventing reentrancy attacks
    uint64 internal _guardCounter;

    address internal _assetIntroducerProxy;
    address internal _dmgIncentivesPool;
    mapping(address => UserStake[]) internal _userToStakesMap;

    enum StakingDuration {
        TWELVE_MONTHS, EIGHTEEN_MONTHS
    }

    struct UserStake {
        bool isWithdrawn;
        uint64 unlockTimestamp;
        address mToken;
        uint amount;
        uint tokenId;
    }

    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;

        _;

        require(
            localCounter == _guardCounter,
            "AssetIntroducerData: REENTRANCY"
        );
    }


}