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

import "../../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";


contract DMGIncentivePool is Ownable {

    using SafeERC20 for IERC20;

    function withdrawTo(
        address __token,
        address __to,
        uint __amount
    )
    external
    onlyOwner {
        _withdraw(__token, __to, __amount);
    }

    function withdrawAllTo(
        address __token,
        address __to
    )
    external
    onlyOwner {
        _withdraw(__token, __to, uint(- 1));
    }

    function enableSpender(
        address __token,
        address __spender
    )
    external
    onlyOwner {
        IERC20(__token).safeApprove(__spender, uint(- 1));
    }

    function disableSpender(
        address __token,
        address __spender
    )
    external
    onlyOwner {
        IERC20(__token).safeApprove(__spender, 0);
    }

    function _withdraw(
        address __token,
        address __to,
        uint __amount
    )
    internal {
        if (__amount == uint(- 1)) {
            __amount = IERC20(__token).balanceOf(address(this));
        }
        IERC20(__token).safeTransfer(__to, __amount);
    }

}