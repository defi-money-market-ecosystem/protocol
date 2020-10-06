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

import "../../utils/Blacklistable.sol";
import "../../utils/ERC20.sol";
import "../../utils/IERC20WithDecimals.sol";

contract ERC20Mock is ERC20, Blacklistable, IERC20WithDecimals {

    uint8 internal _decimals = 18;

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function setDecimals(uint8 __decimals) external {
        _decimals = __decimals;
    }

    function pausable() public view returns (address) {
        return address(this);
    }

    function blacklistable() public view returns (Blacklistable) {
        return Blacklistable(address(this));
    }

    function setBalance(address recipient, uint amount) public {
        mintToThisContract(amount);
        _transfer(address(this), recipient, amount);
    }

    function burn(uint amount) public returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

}
