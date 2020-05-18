pragma solidity ^0.5.0;

import "../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";

import "../interfaces/IUnderlyingTokenValuator.sol";
import "../interfaces/IUsdAggregator.sol";

import "../../utils/StringHelpers.sol";

contract UnderlyingTokenValuatorImplV3 is IUnderlyingTokenValuator, Ownable {

    using StringHelpers for address;
    using SafeMath for uint;

    event DaiUsdAggregatorChanged(address indexed oldAggregator, address indexed newAggregator);
    event EthUsdAggregatorChanged(address indexed oldAggregator, address indexed newAggregator);
    event UsdcEthAggregatorChanged(address indexed oldAggregator, address indexed newAggregator);

    address public dai;
    address public usdc;
    address public weth;

    IUsdAggregator public ethUsdAggregator;
    IUsdAggregator public daiUsdAggregator;
    IUsdAggregator public usdcEthAggregator;

    uint public constant USD_AGGREGATOR_BASE = 100000000;
    uint public constant ETH_AGGREGATOR_BASE = 1e18;

    constructor(
        address _dai,
        address _usdc,
        address _weth,
        address _daiUsdAggregator,
        address _ethUsdAggregator,
        address _usdcEthAggregator
    ) public {
        dai = _dai;
        usdc = _usdc;
        weth = _weth;

        daiUsdAggregator = IUsdAggregator(_daiUsdAggregator);
        ethUsdAggregator = IUsdAggregator(_ethUsdAggregator);
        usdcEthAggregator = IUsdAggregator(_usdcEthAggregator);
    }

    function setDaiUsdAggregator(address _daiUsdAggregator) public onlyOwner {
        address oldAggregator = address(daiUsdAggregator);
        daiUsdAggregator = IUsdAggregator(_daiUsdAggregator);

        emit DaiUsdAggregatorChanged(oldAggregator, _daiUsdAggregator);
    }

    function setEthUsdAggregator(address _ethUsdAggregator) public onlyOwner {
        address oldAggregator = address(ethUsdAggregator);
        ethUsdAggregator = IUsdAggregator(_ethUsdAggregator);

        emit EthUsdAggregatorChanged(oldAggregator, _ethUsdAggregator);
    }

    function setUsdcEthAggregator(address _usdcEthAggregator) public onlyOwner {
        address oldAggregator = address(usdcEthAggregator);
        usdcEthAggregator = IUsdAggregator(_usdcEthAggregator);

        emit UsdcEthAggregatorChanged(oldAggregator, _usdcEthAggregator);
    }

    function getTokenValue(address token, uint amount) public view returns (uint) {
        if (token == weth) {
            return amount.mul(ethUsdAggregator.currentAnswer()).div(USD_AGGREGATOR_BASE);
        } else if (token == usdc) {
            uint wethValueAmount = amount.mul(usdcEthAggregator.currentAnswer()).div(ETH_AGGREGATOR_BASE);
            return getTokenValue(weth, wethValueAmount);
        } else if (token == dai) {
            return amount.mul(daiUsdAggregator.currentAnswer()).div(USD_AGGREGATOR_BASE);
        } else {
            revert(string(abi.encodePacked("Invalid token, found: ", token.toString())));
        }
    }

}
