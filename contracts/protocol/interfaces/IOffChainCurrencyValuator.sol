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

/**
 * Gets the value of any currencies that are residing off-chain, but are NOT yet allocated to a revenue-producing asset.
 */
interface IOffChainCurrencyValuator {

    /**
     * @return The value of the off-chain assets. The number returned uses 18 decimal places.
     */
    function getOffChainCurrenciesValue() external view returns (uint);

}
