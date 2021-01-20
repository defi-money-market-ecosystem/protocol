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
import "../interfaces/IOffChainAssetValuatorV2.sol";
import "../interfaces/IOffChainCurrencyValuatorV2.sol";
import "../interfaces/ICollateralizationCalculator.sol";
import "../mocks/ERC20Mock.sol";

import "../../utils/Blacklistable.sol";

/**
 * @dev A mock implementation of the controller, which ONLY has the functions implemented that the DMM token needs.
 */
contract DmmControllerMock is IDmmController, Ownable, Pausable {

    uint constant EXCHANGE_RATE_BASE_RATE = 1e18;

    uint constant COLLATERALIZATION_BASE_RATE = 1e18;

    uint constant INTEREST_RATE_BASE_RATE = 1e18;

    bool private _isMarketsEnabled;
    mapping(address => address) private _mTokenToTokenMap;
    mapping(address => address) private _tokenToMTokenMap;
    mapping(uint => address) private _tokenIdToMTokenMap;
    mapping(address => uint) private _mTokenToTokenIdMap;
    address private _dmmBlacklistable;
    address private _underlyingTokenValuator;
    address private _offChainAssetsValuator;
    address private _offChainCurrencyValuator;
    address private _collateralizationCalculator;
    uint private _interestRate;
    uint[] private _tokenIds;

    constructor(
        address dmmBlacklistable,
        address underlyingTokenValuator,
        address offChainAssetsValuator,
        address offChainCurrencyValuator,
        address collateralizationCalculator,
        address[] memory mTokens,
        address[] memory underlyingTokens,
        uint interestRate
    ) public {
        _dmmBlacklistable = dmmBlacklistable;
        _underlyingTokenValuator = underlyingTokenValuator;
        offChainAssetsValuator = _offChainAssetsValuator;
        offChainCurrencyValuator = _offChainCurrencyValuator;
        collateralizationCalculator = _collateralizationCalculator;
        _interestRate = interestRate;
        _isMarketsEnabled = true;

        for (uint i = 0; i < mTokens.length; i++) {
            _mTokenToTokenMap[mTokens[i]] = underlyingTokens[i];
            _tokenToMTokenMap[underlyingTokens[i]] = mTokens[i];
            _tokenIdToMTokenMap[i + 1] = mTokens[i];
            _mTokenToTokenIdMap[mTokens[i]] = i + 1;
            _tokenIds.push(i + 1);
        }
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

    function getUnderlyingTokenForDmm(address mToken) public view returns (address) {
        return _mTokenToTokenMap[mToken];
    }

    function getDmmTokenForUnderlying(address underlyingToken) public view returns (address) {
        return _tokenToMTokenMap[underlyingToken];
    }

    function getInterestRateByDmmTokenAddress(address) public view returns (uint) {
        return _interestRate;
    }

    function setInterestRate(uint interestRate) public {
        _interestRate = interestRate;
    }

    function setGuardian(address) public {
        revert("DmmControllerMock::setGuardian: NOT_IMPLEMENTED");
    }

    function setDmmTokenFactory(address) public {
        revert("DmmControllerMock::setDmmTokenFactory: NOT_IMPLEMENTED");
    }

    function setDmmEtherFactory(address) public {
        revert("DmmControllerMock::setDmmEtherFactory: NOT_IMPLEMENTED");
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

    function adminWithdrawFunds(uint tokenId, uint amount) public {
        ERC20Mock(_tokenIdToMTokenMap[tokenId]).setBalance(msg.sender, amount);
    }

    function adminDepositFunds(uint tokenId, uint amount) public {
        ERC20Mock(_tokenIdToMTokenMap[tokenId]).transferFrom(msg.sender, address(this), amount);
        ERC20Mock(_tokenIdToMTokenMap[tokenId]).burn(amount);
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
        return _tokenIds;
    }

    function getExchangeRateByUnderlying(address) public view returns (uint) {
        // 1.1
        //        return 1.1e18;
        return 1e18;
    }

    function getExchangeRate(address) public view returns (uint) {
        // 1.1
        //        return 1.1e18;
        return 1e18;
    }

    function getTokenIdFromDmmTokenAddress(address mToken) public view returns (uint) {
        return _mTokenToTokenIdMap[mToken];
    }

    function getDmmTokenAddressByDmmTokenId(uint tokenId) public view returns (address) {
        return _tokenIdToMTokenMap[tokenId];
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
        revert("DmmControllerMock::NOT_IMPLEMENTED");
    }

    function addMarketFromExistingDmmToken(
        address,
        address
    ) public {
        revert("DmmControllerMock::: addMarketFromExistingDmmTokenNOT_IMPLEMENTED");
    }

    function transferOwnershipToNewController(address) public {
        revert("DmmControllerMock::DmmControllerMock: NOT_IMPLEMENTED");
    }

    function blacklistable() public view returns (Blacklistable) {
        return Blacklistable(_dmmBlacklistable);
    }

    function underlyingTokenValuator() public view returns (IUnderlyingTokenValuator) {
        return IUnderlyingTokenValuator(_underlyingTokenValuator);
    }

    function offChainAssetsValuator() external view returns (IOffChainAssetValuatorV2) {
        return IOffChainAssetValuatorV2(_offChainAssetsValuator);
    }

    function offChainCurrencyValuator() external view returns (IOffChainCurrencyValuatorV2) {
        return IOffChainCurrencyValuatorV2(_offChainCurrencyValuator);
    }

    function collateralizationCalculator() external view returns (ICollateralizationCalculator) {
        return ICollateralizationCalculator(_collateralizationCalculator);
    }

}