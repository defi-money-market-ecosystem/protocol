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

interface IReferralTrackerV1 {

    // *************************
    // ***** Events
    // *************************

    event ProxyMint(
        address indexed referrer,
        address indexed minter,
        address indexed receiver,
        uint amount,
        uint underlyingAmount
    );

    event ProxyRedeem(
        address indexed referrer,
        address indexed redeemer,
        address indexed receiver,
        uint amount,
        uint underlyingAmount
    );

    // *************************
    // ***** User Functions
    // *************************

    /**
     * @return  The amount of mTokens received
     */
    function mintViaEther(
        address referrer,
        address mETH
    ) external payable returns (uint);

    /**
     * @return  The amount of mTokens received
     */
    function mint(
        address referrer,
        address mToken,
        uint underlyingAmount
    ) external returns (uint);

    /**
     * @return  The amount of mTokens received
     */
    function mintFromGaslessRequest(
        address referrer,
        address mToken,
        address owner,
        address recipient,
        uint nonce,
        uint expiry,
        uint amount,
        uint feeAmount,
        address feeRecipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint);

    /**
     * @return  The amount of underlying received
     */
    function redeem(
        address referrer,
        address mToken,
        uint amount
    ) external returns (uint);

    /**
     * @return  The amount of underlying received
     */
    function redeemToEther(
        address referrer,
        address mToken,
        uint amount
    ) external returns (uint);

    /**
     * @return  The amount of underlying received
     */
    function redeemFromGaslessRequest(
        address referrer,
        address mToken,
        address owner,
        address recipient,
        uint nonce,
        uint expiry,
        uint amount,
        uint feeAmount,
        address feeRecipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint);

}