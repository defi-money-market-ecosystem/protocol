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
import "../interfaces/IUsdAggregatorV1.sol";

import "../../utils/StringHelpers.sol";

contract UnderlyingTokenValuatorImplV2 is IUnderlyingTokenValuator, Ownable {

    using StringHelpers for address;
    using SafeMath for uint;

    event EthUsdAggregatorChanged(address indexed oldAggregator, address indexed newAggregator);

    address public dai;
    address public usdc;
    address public weth;

    IUsdAggregatorV1 public ethUsdAggregator;

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

        ethUsdAggregator = IUsdAggregatorV1(_ethUsdAggregator);
    }

    function setEthUsdAggregator(address _ethUsdAggregator) public onlyOwner {
        address oldAggregator = address(ethUsdAggregator);
        ethUsdAggregator = IUsdAggregatorV1(_ethUsdAggregator);

        emit EthUsdAggregatorChanged(oldAggregator, _ethUsdAggregator);
    }

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
