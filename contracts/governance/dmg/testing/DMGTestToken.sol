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


pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../SafeBitMath.sol";
import "../DMGToken.sol";

/**
 * A test variant of the DMG governance token, which includes a faucet.
 */
contract DMGTestToken is DMGToken {

    using SafeMath for uint;
    using SafeBitMath for uint128;

    function addBalance(uint amount) public {
        _addBalance(msg.sender, amount);
    }

    function addBalance(address recipient, uint amount) public {
        _addBalance(recipient, amount);
    }

    function subtractBalance(uint amount) public {
        _subtractBalance(msg.sender, amount);
    }

    function subtractBalance(address recipient, uint amount) public {
        _subtractBalance(recipient, amount);
    }

    function _addBalance(address recipient, uint amount) internal {
        require(uint128(amount) == amount, "DMG::addBalance invalid amount");

        totalSupply = totalSupply.add(amount);
        balances[address(this)] = balances[address(this)].add128(uint128(amount));
        _transferTokens(address(this), recipient, uint128(amount));
    }

    function _subtractBalance(address recipient, uint amount) internal {
        require(uint128(amount) == amount, "DMG::subtractBalance invalid amount");

        totalSupply = totalSupply.sub(amount);
        _transferTokens(recipient, address(this), uint128(amount));
        balances[address(this)] = balances[address(this)].sub128(uint128(amount));
    }

}