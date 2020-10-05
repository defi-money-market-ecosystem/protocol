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

import "../../../node_modules/@openzeppelin/contracts/lifecycle/Pausable.sol";
import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";

import "../interfaces/IDmmController.sol";

import "../../utils/Blacklistable.sol";

/**
 * @dev A mock implementation of the controller, which ONLY has the functions implemented that the DMM token needs.
 */
contract DmmControllerMock is IDmmController, Ownable, Pausable {

    bool private _isMarketsEnabled;
    address private _token;
    address private _dmmBlacklistable;
    address private _underlyingTokenValuator;
    uint private _interestRate;

    constructor(
        address dmmBlacklistable,
        address underlyingTokenValuator,
        address token,
        uint interestRate
    ) public {
        _dmmBlacklistable = dmmBlacklistable;
        _underlyingTokenValuator = underlyingTokenValuator;
        _token = token;
        _interestRate = interestRate;
        _isMarketsEnabled = true;
    }

    function enableMarket(uint) public {
        _isMarketsEnabled = true;
    }

    function disableMarket(uint) public {
        _isMarketsEnabled = false;
    }

    function setMarketsEnabled(bool isMarketsEnabled) public onlyOwner {
        _isMarketsEnabled = isMarketsEnabled;
    }

    function isMarketEnabledByDmmTokenId(uint) public view returns (bool) {
        return _isMarketsEnabled;
    }

    function isMarketEnabledByDmmTokenAddress(address) public view returns (bool) {
        return _isMarketsEnabled;
    }

    function getUnderlyingTokenForDmm(address) public view returns (address) {
        return _token;
    }

    function getDmmTokenForUnderlying(address) public view returns (address) {
        revert("NOT_IMPLEMENTED");
    }

    function getInterestRateByDmmTokenAddress(address) public view returns (uint) {
        return _interestRate;
    }

    function setInterestRate(uint interestRate) public {
        _interestRate = interestRate;
    }

    function setGuardian(address) public {
        revert("NOT_IMPLEMENTED");
    }

    function setDmmTokenFactory(address) public {
        revert("NOT_IMPLEMENTED");
    }

    function setDmmEtherFactory(address) public {
        revert("NOT_IMPLEMENTED");
    }

    function setInterestRateInterface(address) public {
    }

    function setOffChainAssetValuator(address) public {
    }

    function setOffChainCurrencyValuator(address) public {
    }

    function setUnderlyingTokenValuator(address underlyingTokenValuator) public {
        _underlyingTokenValuator = underlyingTokenValuator;
    }

    function setMinCollateralization(uint) public {
    }

    function setMinReserveRatio(uint) public {
    }

    function increaseTotalSupply(uint, uint) public {
    }

    function decreaseTotalSupply(uint, uint) public {
    }

    function adminWithdrawFunds(uint, uint) public {
    }

    function adminDepositFunds(uint, uint) public {
    }

    function getTotalCollateralization() public view returns (uint) {
        return 1e18;
    }

    function getActiveCollateralization() public view returns (uint) {
        return 1e18;
    }

    function getInterestRateByUnderlyingTokenAddress(address) public view returns (uint) {
        return _interestRate;
    }

    function getInterestRateByDmmTokenId(uint) public view returns (uint) {
        return _interestRate;
    }

    function getDmmTokenIds() external view returns (uint[] memory) {
        return new uint[](0);
    }

    function getExchangeRateByUnderlying(address) public view returns (uint) {
        revert("NOT_IMPLEMENTED");
    }

    function getExchangeRate(address) public view returns (uint) {
        revert("NOT_IMPLEMENTED");
    }

    function getTokenIdFromDmmTokenAddress(address) public view returns (uint) {
        revert("NOT_IMPLEMENTED");
    }

    function getDmmTokenAddressByDmmTokenId(uint) public view returns (address) {
        revert("NOT_IMPLEMENTED");
    }

    function addMarket(
        address,
        string memory,
        string memory,
        uint8,
        uint,
        uint,
        uint
    ) public {
        revert("NOT_IMPLEMENTED");
    }

    function addMarketFromExistingDmmToken(
        address,
        address
    ) public {
        revert("NOT_IMPLEMENTED");
    }

    function transferOwnershipToNewController(
        address
    ) public {
        revert("NOT_IMPLEMENTED");
    }

    function blacklistable() public view returns (Blacklistable) {
        return Blacklistable(_dmmBlacklistable);
    }

    function underlyingTokenValuator() public view returns (IUnderlyingTokenValuator) {
        return IUnderlyingTokenValuator(_underlyingTokenValuator);
    }

}