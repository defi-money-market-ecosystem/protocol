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

    function enableMarket(uint dmmTokenId) public {
        _isMarketsEnabled = true;
    }

    function disableMarket(uint dmmTokenId) public {
        _isMarketsEnabled = false;
    }

    function setMarketsEnabled(bool isMarketsEnabled) public onlyOwner {
        _isMarketsEnabled = isMarketsEnabled;
    }

    function isMarketEnabledByDmmTokenId(uint dmmTokenId) public view returns (bool) {
        return _isMarketsEnabled;
    }

    function isMarketEnabledByDmmTokenAddress(address dmmToken) public view returns (bool) {
        return _isMarketsEnabled;
    }

    function getUnderlyingTokenForDmm(address dmmToken) public view returns (address) {
        return _token;
    }

    function getDmmTokenForUnderlying(address dmmToken) public view returns (address) {
        revert("NOT_IMPLEMENTED");
    }

    function getInterestRateByDmmTokenAddress(address dmmToken) public view returns (uint) {
        return _interestRate;
    }

    function setInterestRate(uint interestRate) public {
        _interestRate = interestRate;
    }

    function setGuardian(address newGuardian) public {
        revert("NOT_IMPLEMENTED");
    }

    function setDmmTokenFactory(address newDmmTokenFactory) public {
        revert("NOT_IMPLEMENTED");
    }

    function setDmmEtherFactory(address newDmmEtherFactory) public {
        revert("NOT_IMPLEMENTED");
    }

    function setInterestRateInterface(address unused) public {
    }

    function setOffChainAssetValuator(address unused) public {
    }

    function setOffChainCurrencyValuator(address unused) public {
    }

    function setUnderlyingTokenValuator(address underlyingTokenValuator) public {
        _underlyingTokenValuator = underlyingTokenValuator;
    }

    function setMinCollateralization(uint unused) public {
    }

    function setMinReserveRatio(uint unused) public {
    }

    function increaseTotalSupply(uint dmmTokenId, uint amount) public {
    }

    function decreaseTotalSupply(uint dmmTokenId, uint amount) public {
    }

    function adminWithdrawFunds(uint dmmTokenId, uint256 underlyingAmount) public {
    }

    function adminDepositFunds(uint dmmTokenId, uint256 underlyingAmount) public {
    }

    function getTotalCollateralization() public view returns (uint) {
        return 1e18;
    }

    function getActiveCollateralization() public view returns (uint) {
        return 1e18;
    }

    function getInterestRateByUnderlyingTokenAddress(address underlyingToken) public view returns (uint) {
        return _interestRate;
    }

    function getInterestRateByDmmTokenId(uint dmmTokenId) public view returns (uint) {
        return _interestRate;
    }

    function getDmmTokenIds() external view returns (uint[] memory) {
        return new uint[](0);
    }

    function getExchangeRateByUnderlying(address underlyingTokenAddress) public view returns (uint) {
        revert("NOT_IMPLEMENTED");
    }

    function getExchangeRate(address dmmTokenAddress) public view returns (uint) {
        revert("NOT_IMPLEMENTED");
    }

    function getTokenIdFromDmmTokenAddress(address dmmTokenAddress) public view returns (uint) {
        revert("NOT_IMPLEMENTED");
    }

    function getDmmTokenAddressByDmmTokenId(uint dmmTokenId) public view returns (address) {
        revert("NOT_IMPLEMENTED");
    }

    function addMarket(
        address underlyingToken,
        string memory symbol,
        string memory name,
        uint8 decimals,
        uint minMintAmount,
        uint minRedeemAmount,
        uint totalSupply
    ) public {
        revert("NOT_IMPLEMENTED");
    }

    function addMarketFromExistingDmmToken(
        address dmmToken,
        address underlyingToken
    ) public {
        revert("NOT_IMPLEMENTED");
    }

    function transferOwnershipToNewController(
        address newController
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