pragma solidity ^0.5.0;

import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "../utils/Blacklistable.sol";

/**
 * @dev A mock implementation of the controller, which ONLY has the functions implemented that the DMM token needs.
 */
contract DmmControllerMock is Ownable, Pausable {

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

    function setMarketsEnabled(bool isMarketsEnabled) public onlyOwner {
        _isMarketsEnabled = isMarketsEnabled;
    }

    function isMarketEnabled(address dmmToken) public view returns (bool) {
        return _isMarketsEnabled;
    }

    function getUnderlyingTokenForDmm(address dmmToken) public view returns (address) {
        return _token;
    }

    function getInterestRate(address dmmToken) public view returns (uint) {
        return _interestRate;
    }

    function setInterestRate(uint interestRate) public {
        _interestRate = interestRate;
    }

}