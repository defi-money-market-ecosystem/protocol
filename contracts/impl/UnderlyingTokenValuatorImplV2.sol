pragma solidity ^0.5.0;

import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";

import "../interfaces/IUnderlyingTokenValuator.sol";
import "../libs/StringHelpers.sol";
import "../interfaces/IUsdAggregator.sol";

contract UnderlyingTokenValuatorImplV2 is IUnderlyingTokenValuator, Ownable {

    using StringHelpers for address;
    using SafeMath for uint;

    event EthUsdAggregatorChanged(address indexed oldAggregator, address indexed newAggregator);

    address public dai;
    address public usdc;
    address public weth;

    IUsdAggregator public ethUsdAggregator;

    uint public constant USD_AGGREGATOR_BASE = 100000000;

    constructor(
        address _dai,
        address _usdc,
        address _weth,
        address _ethUsdAggregator
    ) public {
        dai = _dai;
        usdc = _usdc;
        weth = _weth;

        ethUsdAggregator = IUsdAggregator(_ethUsdAggregator);
    }

    function setEthUsdAggregator(address _ethUsdAggregator) public onlyOwner {
        address oldAggregator = address(ethUsdAggregator);
        ethUsdAggregator = IUsdAggregator(_ethUsdAggregator);

        emit EthUsdAggregatorChanged(oldAggregator, _ethUsdAggregator);
    }

    // For right now, we use stable-coins, which we assume are worth $1.00
    function getTokenValue(address token, uint amount) public view returns (uint) {
        if (token == weth) {
            return amount.mul(ethUsdAggregator.currentAnswer()).div(USD_AGGREGATOR_BASE);
        } else if (token == usdc) {
            return amount;
        } else if (token == dai) {
            return amount;
        } else {
            revert(string(abi.encodePacked("Invalid token, found: ", token.toString())));
        }
    }

}
