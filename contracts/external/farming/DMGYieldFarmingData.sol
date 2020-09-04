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

import "../../../node_modules/@openzeppelin/upgrades/contracts/Initializable.sol";

contract DMGYieldFarmingData is Initializable {

    // /////////////////////////
    // BEGIN State Variables
    // /////////////////////////

    // counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;
    address internal _owner;

    address internal _dmgToken;
    address internal _guardian;
    address internal _dmmController;
    address[] internal _supportedFarmTokens;
    /// @notice How much DMG is earned every second of farming. This number is represented as a fraction with 18
    //          decimal places, whereby 0.01 == 1000000000000000.
    uint internal _dmgGrowthCoefficient;

    bool internal _isFarmActive;
    uint internal _seasonIndex;
    mapping(address => uint16) internal _tokenToRewardPointMap;
    mapping(address => mapping(address => bool)) internal _userToSpenderToIsApprovedMap;
    mapping(uint => mapping(address => mapping(address => uint))) internal _seasonIndexToUserToTokenToEarnedDmgAmountMap;
    mapping(uint => mapping(address => mapping(address => uint64))) internal _seasonIndexToUserToTokenToDepositTimestampMap;
    mapping(address => address) internal _tokenToUnderlyingTokenMap;
    mapping(address => uint8) internal _tokenToDecimalsMap;
    mapping(address => uint) internal _tokenToIndexPlusOneMap;
    mapping(address => mapping(address => uint)) internal _addressToTokenToBalanceMap;
    mapping(address => bool) internal _globalProxyToIsTrustedMap;

    // /////////////////////////
    // END State Variables
    // /////////////////////////

    // /////////////////////////
    // Events
    // /////////////////////////

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // /////////////////////////
    // Functions
    // /////////////////////////

    function initialize(address owner) public initializer {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;

        _owner = owner;
        emit OwnershipTransferred(address(0), owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "DMGYieldFarmingData::transferOwnership: INVALID_OWNER");

        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    // /////////////////////////
    // Modifiers
    // /////////////////////////

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "DMGYieldFarmingData: NOT_OWNER");
        _;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "DMGYieldFarmingData: REENTRANCY");
    }

    // /////////////////////////
    // Constants
    // /////////////////////////

    uint8 public constant POINTS_DECIMALS = 2;

    uint16 public constant POINTS_FACTOR = 10 ** uint16(POINTS_DECIMALS);

    uint8 public constant DMG_GROWTH_COEFFICIENT_DECIMALS = 18;

    uint public constant DMG_GROWTH_COEFFICIENT_FACTOR = 10 ** uint(DMG_GROWTH_COEFFICIENT_DECIMALS);

    uint8 public constant USD_VALUE_DECIMALS = 18;

    uint public constant USD_VALUE_FACTOR = 10 ** uint(USD_VALUE_DECIMALS);

}