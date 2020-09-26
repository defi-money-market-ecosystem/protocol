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

import "../interfaces/IUsdAggregatorV2.sol";

import "./UnderlyingTokenValuatorImplV3.sol";

contract UnderlyingTokenValuatorImplV4 is UnderlyingTokenValuatorImplV3 {

    using SafeMath for uint;

    event UsdtEthAggregatorChanged(address indexed oldAggregator, address indexed newAggregator);

    address public usdt;

    IUsdAggregatorV2 public usdtEthAggregator;

    constructor(
        address _dai,
        address _usdc,
        address _usdt,
        address _weth,
        address _daiUsdAggregator,
        address _ethUsdAggregator,
        address _usdcEthAggregator,
        address _usdtEthAggregator
    ) public UnderlyingTokenValuatorImplV3(
        _dai, _usdc, _weth, _daiUsdAggregator, _ethUsdAggregator, _usdcEthAggregator
    ) {
        usdt = _usdt;
        usdtEthAggregator = IUsdAggregatorV2(_usdtEthAggregator);
    }

    function setUsdtEthAggregator(address _usdtEthAggregator) public onlyOwner {
        address oldAggregator = address(usdtEthAggregator);
        usdtEthAggregator = IUsdAggregatorV2(_usdtEthAggregator);
        emit UsdtEthAggregatorChanged(oldAggregator, _usdtEthAggregator);
    }

    function getTokenValue(address token, uint amount) public view returns (uint) {
        if (token == usdt) {
            uint wethValueAmount = amount.mul(usdtEthAggregator.latestAnswer()).div(ETH_AGGREGATOR_BASE);
            return getTokenValue(weth, wethValueAmount);
        } else {
            return super.getTokenValue(token, amount);
        }
    }

}