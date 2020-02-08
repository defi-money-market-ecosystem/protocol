pragma solidity ^0.5.0;

import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

/**
 * @dev A mock implementation of the controller, which ONLY has the functions implemented that the DMM token needs.
 */
contract DmmControllerMock is Ownable, Pausable {

    bool private _isMarketsEnabled;
    address private _token;
    address private _dmmBlacklistable;

    constructor(
        address dmmBlacklistable,
        address token
    ) public {
        _dmmBlacklistable = dmmBlacklistable;
        _token = token;
        _isMarketsEnabled = false;
    }

    function blacklistable() public view returns (address) {
        return _dmmBlacklistable;
    }

    function setMarketsEnabled(bool isMarketsEnabled) public onlyOwner {
        _isMarketsEnabled = isMarketsEnabled;
    }

    function isMarketEnabled(address dmmToken) public view onlyOwner returns (bool) {
        return _isMarketsEnabled;
    }

    function getUnderlyingTokenForDmm(address dmmToken) public view returns (address) {
        return _token;
    }

}