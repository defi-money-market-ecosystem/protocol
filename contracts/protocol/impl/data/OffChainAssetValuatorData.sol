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

import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../../node_modules/@openzeppelin/upgrades/contracts/Initializable.sol";

import "../../../external/chainlink/UpgradeableChainlinkClient.sol";

import "../OwnableOrGuardian.sol";

contract OffChainAssetValuatorData is IOwnableOrGuardian, UpgradeableChainlinkClient  {

    using SafeERC20 for IERC20;

    // ****************************************
    // ***** State Variables - DO NOT MODIFY
    // ****************************************

    /// The amount of LINK to be paid per request
    uint internal _oraclePayment;

    /// The job ID that's fired on the LINK nodes to fulfill this contract's need for off-chain data
    bytes32 internal _offChainAssetsValueJobId;

    /// The value of all off-chain collateral, as determined by Chainlink. This number has 18 decimal places of precision.
    uint internal _offChainAssetsValue;

    /// The timestamp (in Unix seconds) at which this contract's _offChainAssetsValue field was last updated.
    uint internal _lastUpdatedTimestamp;

    /// The block number at which this contract's _offChainAssetsValue field was last updated.
    uint internal _lastUpdatedBlockNumber;

    /// All of the supported asset types
    bytes32[] internal _allAssetTypes;

    /// All of the supported asset types, represented as a mapping
    mapping(bytes32 => uint) internal _assetTypeToNumberOfUsesMap;

    /// A mapping from asset introducer (token ID) to an asset type, to whether or not it's supported.
    mapping(uint => mapping(bytes32 => bool)) internal _assetIntroducerToAssetTypeToIsSupportedMap;

    // *************************
    // ***** Functions
    // *************************

    function deposit(address token, uint amount) public onlyOwnerOrGuardian {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address token, address recipient, uint amount) public onlyOwnerOrGuardian {
        IERC20(token).safeTransfer(recipient, amount);
    }

}