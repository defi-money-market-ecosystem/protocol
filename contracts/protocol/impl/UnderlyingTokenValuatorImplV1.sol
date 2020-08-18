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

import "../interfaces/IUnderlyingTokenValuator.sol";

import "../../utils/StringHelpers.sol";

contract UnderlyingTokenValuatorImplV1 is IUnderlyingTokenValuator {

    using StringHelpers for address;

    address public dai;
    address public usdc;

    constructor(
        address _dai,
        address _usdc
    ) public {
        dai = _dai;
        usdc = _usdc;
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
