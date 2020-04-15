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
    uint private _interestRate;

    constructor(
        address dmmBlacklistable,
        address token,
        uint interestRate
    ) public {
        _dmmBlacklistable = dmmBlacklistable;
        _token = token;
        _interestRate = interestRate;
        _isMarketsEnabled = true;
    }

    function blacklistable() public view returns (Blacklistable) {
        return Blacklistable(_dmmBlacklistable);
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

    function setInterestRateInterface(address unused) public {
    }

    function setOffChainAssetValuator(address unused) public {
    }

    function setOffChainCurrencyValuator(address unused) public {
    }

    function setUnderlyingTokenValuator(address unused) public {
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

    function getExchangeRateByUnderlying(address underlyingTokenAddress) public view returns (uint) {
        revert("NOT_IMPLEMENTED");
    }

    function getExchangeRate(address dmmTokenAddress) public view returns (uint) {
        revert("NOT_IMPLEMENTED");
    }

    function getTokenIdFromDmmTokenAddress(address dmmTokenAddress) public view returns (uint) {
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

}