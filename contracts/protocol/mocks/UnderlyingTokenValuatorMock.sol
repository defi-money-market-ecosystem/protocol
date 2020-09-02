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

import "../interfaces/IUnderlyingTokenValuator.sol";

contract UnderlyingTokenValuatorMock is IUnderlyingTokenValuator {

    using SafeMath for uint;

    mapping(address => uint) public tokenToPriceMap;
    mapping(address => uint8) public tokenToPriceDecimalsMap;

    constructor(
        address[] memory tokens,
        uint[] memory prices,
        uint8[] memory priceDecimals
    ) public {
        require(
            tokens.length == prices.length,
            "UnderlyingTokenValuatorMock: INVALID_LENGTH"
        );
        require(
            tokens.length == priceDecimals.length,
            "UnderlyingTokenValuatorMock: INVALID_LENGTH"
        );

        for (uint i = 0; i < tokens.length; i++) {
            require(
                prices[i] != 0,
                "UnderlyingTokenValuatorMock: INVALID_PRICE"
            );
            require(
                priceDecimals[i] != 0,
                "UnderlyingTokenValuatorMock: INVALID_PRICE"
            );

            tokenToPriceMap[tokens[i]] = prices[i];
            tokenToPriceDecimalsMap[tokens[i]] = priceDecimals[i];
        }
    }

    function getTokenValue(
        address token,
        uint amount
    ) public view returns (uint) {
        require(
            tokenToPriceMap[token] != 0,
            "UnderlyingTokenValuatorMock::getTokenValue: INVALID_TOKEN"
        );

        return tokenToPriceMap[token].mul(amount).div(10 ** tokenToPriceDecimalsMap[token]);
    }

}