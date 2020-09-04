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

import "../interfaces/IWETH.sol";
import "../../utils/AddressUtil.sol";
import "./ERC20Mock.sol";

contract WETHMock is ERC20Mock, IWETH {

    event Deposit(address indexed sender, uint wad);
    event Withdrawal(address indexed sender, uint wad);

    string constant public name = "Wrapped Ether";
    string constant public symbol = "WETH";
    uint8 constant public decimals = 18;

    constructor() public {
    }

    function() external payable {
        deposit();
    }

    function deposit() public payable {
        _balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint wad) public {
        require(_balances[msg.sender] >= wad, "INSUFFICIENT_BALANCE");

        _balances[msg.sender] -= wad;
        AddressUtil.sendETHAndVerify(msg.sender, wad);
        emit Withdrawal(msg.sender, wad);
    }

}