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
import "../interfaces/IUnderlyingTokenValuator.sol";
import "../interfaces/IUnderlyingTokenValuatorV5.sol";

import "./OwnableOrGuardian.sol";
import "./data/UnderlyingTokenValuatorData.sol";

contract UnderlyingTokenValuatorImplV5 is IUnderlyingTokenValuator, IUnderlyingTokenValuatorV5, UnderlyingTokenValuatorData {

    using SafeMath for uint;

    /**
     * Note, these arrays are set up, such that each index corresponds with one-another.
     *
     * @param tokens                The tokens that are supported by this adapter.
     * @param chainlinkAggregators  The Chainlink aggregators that have on-chain prices.
     * @param quoteSymbols          The token against which this token's value is compared using the aggregator. The
     *                              zero address corresponds with USD.
     */
    function initialize(
        address owner,
        address guardian,
        address weth,
        address[] calldata tokens,
        address[] calldata chainlinkAggregators,
        address[] calldata quoteSymbols
    )
    external
    initializer {
        require(
            tokens.length == chainlinkAggregators.length,
            "UnderlyingTokenValuatorImplV5: INVALID_AGGREGATORS"
        );
        require(
            chainlinkAggregators.length == quoteSymbols.length,
            "UnderlyingTokenValuatorImplV5: INVALID_TOKEN_PAIRS"
        );

        IOwnableOrGuardian.initialize(owner, guardian);

        _weth = weth;

        for (uint i = 0; i < tokens.length; i++) {
            _insertOrUpdateOracleToken(tokens[i], chainlinkAggregators[i], quoteSymbols[i]);
        }
    }

    // ============ Admin Functions ============

    function insertOrUpdateOracleToken(
        address token,
        address chainlinkAggregator,
        address quoteSymbol
    )
    public
    onlyOwnerOrGuardian {
        _insertOrUpdateOracleToken(token, chainlinkAggregator, quoteSymbol);
    }

    // ============ Public Functions ============

    function weth() external view returns (address) {
        return _weth;
    }

    function getAggregatorByToken(
        address token
    ) external view returns (address) {
        return address(_tokenToAggregatorMap[token]);
    }

    function getQuoteSymbolByToken(
        address token
    ) external view returns (address) {
        return _tokenToQuoteSymbolMap[token];
    }

    function getTokenValue(
        address token,
        uint amount
    )
    public
    view
    returns (uint) {
        require(
            address(_tokenToAggregatorMap[token]) != address(0),
            "UnderlyingTokenValuatorImplV5::getTokenValue: INVALID_TOKEN"
        );

        uint chainlinkPrice = uint(_tokenToAggregatorMap[token].latestAnswer());
        address quoteSymbol = _tokenToQuoteSymbolMap[token];

        if (quoteSymbol == address(0)) {
            // The pair has a USD base, we are done.
            return amount.mul(chainlinkPrice).div(CHAINLINK_USD_FACTOR);
        } else if (quoteSymbol == _weth) {
            // The price we just got and converted is NOT against USD. So we need to get its pair's price against USD.
            // We can do so by recursively calling #getTokenValue using the `quoteSymbol` as the parameter instead of `token`.
            return getTokenValue(quoteSymbol, amount.mul(chainlinkPrice).div(CHAINLINK_ETH_FACTOR));
        } else {
            revert("UnderlyingTokenValuatorImplV5::getTokenValue: INVALID_QUOTE_SYMBOL");
        }
    }

    // ============ Internal Functions ============

    function _insertOrUpdateOracleToken(
        address token,
        address chainlinkAggregator,
        address quoteSymbol
    ) internal {
        _tokenToAggregatorMap[token] = IUsdAggregatorV2(chainlinkAggregator);
        if (quoteSymbol != address(0)) {
            // The aggregator's price is NOT against USD. Therefore, we need to store what it's against as well as the
            // # of decimals the aggregator's price has.
            _tokenToQuoteSymbolMap[token] = quoteSymbol;
        }
        emit TokenInsertedOrUpdated(token, chainlinkAggregator, quoteSymbol);
    }

}
