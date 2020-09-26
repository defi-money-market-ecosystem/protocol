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

interface IUnderlyingTokenValuatorV5 {

    // ============ Events ============

    event TokenInsertedOrUpdated(
        address indexed token,
        address indexed aggregator,
        address indexed quoteSymbol
    );

    // ============ Admin Functions ============

    function initialize(
        address owner,
        address guardian,
        address weth,
        address[] calldata tokens,
        address[] calldata chainlinkAggregators,
        address[] calldata quoteSymbols
    ) external;

    function insertOrUpdateOracleToken(
        address token,
        address chainlinkAggregator,
        address quoteSymbol
    ) external;

    // ============ Public Functions ============

    function weth() external view returns (address);

    function getAggregatorByToken(
        address token
    ) external view returns (address);

    function getQuoteSymbolByToken(
        address token
    ) external view returns (address);

    function getTokenValue(
        address token,
        uint amount
    ) external view returns (uint);

}
