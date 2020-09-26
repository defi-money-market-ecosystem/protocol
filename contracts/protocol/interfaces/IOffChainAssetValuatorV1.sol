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

interface IOffChainAssetValuatorV1 {

    event AssetsValueUpdated(uint newAssetsValue);

    /**
     * @dev Gets the DMM ecosystem's collateral's value from Chainlink's on-chain data feed.
     *
     * @return The value of the ecosystem's collateral, as a number with 18 decimals
     */
    function getOffChainAssetsValue() external view returns (uint);

}
