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

import "../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";

import "../interfaces/IUnderlyingTokenValuator.sol";
import "../interfaces/IUsdAggregatorV2.sol";

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

    IUsdAggregatorV2 public daiUsdAggregator;
    IUsdAggregatorV2 public ethUsdAggregator;

    IUsdAggregatorV2 public usdcEthAggregator;

    uint public constant USD_AGGREGATOR_BASE = 100000000; // 1e8
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

        ethUsdAggregator = IUsdAggregatorV2(_ethUsdAggregator);

        daiUsdAggregator = IUsdAggregatorV2(_daiUsdAggregator);
        usdcEthAggregator = IUsdAggregatorV2(_usdcEthAggregator);
    }

    function setEthUsdAggregator(address _ethUsdAggregator) public onlyOwner {
        address oldAggregator = address(ethUsdAggregator);
        ethUsdAggregator = IUsdAggregatorV2(_ethUsdAggregator);

        emit EthUsdAggregatorChanged(oldAggregator, _ethUsdAggregator);
    }

    function setDaiUsdAggregator(address _daiUsdAggregator) public onlyOwner {
        address oldAggregator = address(daiUsdAggregator);
        daiUsdAggregator = IUsdAggregatorV2(_daiUsdAggregator);

        emit DaiUsdAggregatorChanged(oldAggregator, _daiUsdAggregator);
    }

    function setUsdcEthAggregator(address _usdcEthAggregator) public onlyOwner {
        address oldAggregator = address(usdcEthAggregator);
        usdcEthAggregator = IUsdAggregatorV2(_usdcEthAggregator);

        emit UsdcEthAggregatorChanged(oldAggregator, _usdcEthAggregator);
    }

    function getTokenValue(address token, uint amount) public view returns (uint) {
        if (token == weth) {
            return amount.mul(ethUsdAggregator.latestAnswer()).div(USD_AGGREGATOR_BASE);
        } else if (token == usdc) {
            uint wethValueAmount = amount.mul(usdcEthAggregator.latestAnswer()).div(ETH_AGGREGATOR_BASE);
            return getTokenValue(weth, wethValueAmount);
        } else if (token == dai) {
            return amount.mul(daiUsdAggregator.latestAnswer()).div(USD_AGGREGATOR_BASE);
        } else {
            revert(string(abi.encodePacked("Invalid token, found: ", token.toString())));
        }
    }

}
