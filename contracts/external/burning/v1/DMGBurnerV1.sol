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

import "../../../../node_modules/@openzeppelin/upgrades/contracts/Initializable.sol";
import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../../governance/dmg/IDMGToken.sol";
import "../interfaces/IUniswapV2Router01.sol";

import "../DMGBurnerData.sol";
import "./IDMGBurnerV1.sol";
import "./IDMGBurnerV1Initializable.sol";

contract DMGBurnerV1 is IDMGBurnerV1, IDMGBurnerV1Initializable, DMGBurnerData {

    using SafeERC20 for IERC20;

    event DmgBurned(address indexed burner, uint amount);

    function initialize(
        address __uniswapV2Router,
        address __dmg
    )
    public
    initializer {
        _uniswapV2Router = __uniswapV2Router;
        _dmg = __dmg;
    }

    function uniswapV2Router() public view returns (address) {
        return _uniswapV2Router;
    }

    function dmg() public view returns (address) {
        return _dmg;
    }

    function isTokenEnabled(
        address token
    )
    public
    view returns (bool)  {
        return _tokenToIsSetup[token];
    }

    function enableToken(
        address token
    )
    public {
        require(
            !_tokenToIsSetup[token],
            "DMGBurner::setupToken: TOKEN_ALREADY_SETUP"
        );
        IERC20(token).safeApprove(_uniswapV2Router, uint(- 1));
        _tokenToIsSetup[token] = true;
    }

    function enableTokens(
        address[] memory tokens
    )
    public {
        for (uint i = 0; i < tokens.length; i++) {
            enableToken(tokens[i]);
        }
    }

    function burnDmg(
        address token,
        uint amount,
        address[] memory path
    )
    public
    returns (uint) {
        address dmg = _dmg;
        require(
            path.length >= 2,
            "DMGBurnerV1::burnDmg: INVALID_LENGTH"
        );
        require(
            path[0] == token,
            "DMGBurnerV1::burnDmg: INVALID_HEAD_TOKEN"
        );
        require(
            path[path.length - 1] == dmg,
            "DMGBurnerV1::burnDmg: INVALID_LAST_TOKEN"
        );

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint[] memory amounts = IUniswapV2Router01(_uniswapV2Router).swapExactTokensForTokens(
            amount,
            1e18 /* We should get at least 1 DMG back, or else this is a pointless burn */,
            path,
            address(this),
            block.timestamp + 1
        );
        uint burnAmount = amounts[amounts.length - 1];

        IDMGToken(dmg).burn(burnAmount);

        emit DmgBurned(msg.sender, burnAmount);

        return burnAmount;
    }

}