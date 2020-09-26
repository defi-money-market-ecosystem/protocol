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

import "../../interfaces/IUsdAggregatorV2.sol";
import "../../interfaces/IOwnableOrGuardian.sol";


contract UnderlyingTokenValuatorData is IOwnableOrGuardian {

    // ============ State Values ============

    address internal _weth;

    mapping(address => IUsdAggregatorV2) internal _tokenToAggregatorMap;

    // Defaults to USD if the value is the ZERO address
    mapping(address => address) internal _tokenToQuoteSymbolMap;

    // ============ Constants ============

    uint8 public constant CHAINLINK_USD_DECIMALS = 8;
    uint public constant CHAINLINK_USD_FACTOR = 10 ** uint(CHAINLINK_USD_DECIMALS);

    uint8 public constant CHAINLINK_ETH_DECIMALS = 18;
    uint public constant CHAINLINK_ETH_FACTOR = 10 ** uint(CHAINLINK_ETH_DECIMALS);

}