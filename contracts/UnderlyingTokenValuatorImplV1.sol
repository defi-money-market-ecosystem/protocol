pragma solidity ^0.5.0;

import "./interfaces/IUnderlyingTokenValuator.sol";
import "./libs/StringHelpers.sol";

contract UnderlyingTokenValuatorImplV1 is IUnderlyingTokenValuator {

    using StringHelpers for address;

    address public usdc;
    address public dai;

    constructor(
        address _usdc,
        address _dai
    ) public {
        usdc = _usdc;
        dai = _dai;
    }

    // For right now, we use stable-coins, which we assume are worth $1.00
    function getTokenValue(address token, uint amount) public view returns (uint) {
        if (token == usdc) {
            return amount;
        } else if (token == dai) {
            return amount;
        } else {
            revert(string(abi.encodePacked("Invalid token, found: ", token.toString())));
        }
    }

}
