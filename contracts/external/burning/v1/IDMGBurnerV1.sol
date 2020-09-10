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
 * The DMG Burner uses the UniswapV2 router to sell tokens in exchange for DMG, at market price, and burns the received
 * amount.
 */
interface IDMGBurnerV1 {

    /**
     * @return  The address of the UniswapV2 Router
     */
    function uniswapV2Router() external view returns (address);

    /**
     * @return  The address of the DMG token
     */
    function dmg() external view returns (address);

    /**
     * @return  True if the token is setup and ready to be used to pay for burns, or false if it's not.
     */
    function isTokenEnabled(address token) external view returns (bool);

    /**
     * Sets up a token to be enabled for buying DMG during burn events
     */
    function enableToken(address token) external;

    /**
     * Sets up tokens to be enabled for buying DMG during burn events
     */
    function enableTokens(address[] calldata token) external;

    /**
     * @param token     The token that will be swapped in exchange for DMG
     * @param amount    The amount of `token` that will be swapped on UniswapV2 in exchange for DMG
     * @param path      The path that should be taken to get from `token` to DMG
     * @return          The amount of DMG burned
     */
    function burnDmg(address token, uint amount, address[] calldata path) external returns (uint);

}