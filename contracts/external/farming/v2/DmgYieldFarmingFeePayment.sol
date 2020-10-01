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

import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../../uniswap/interfaces/IUniswapV2Pair.sol";
import "../../uniswap/interfaces/IUniswapV2Router02.sol";
import "../../uniswap/libs/UniswapV2Library.sol";

import "../../../governance/dmg/IDMGToken.sol";

import "../DMGYieldFarmingData.sol";
import "./DMGYieldFarmingV2Lib.sol";
import "./IDMGYieldFarmingV2.sol";


contract DmgYieldFarmingFeePayment is IDMGYieldFarmingV2, DMGYieldFarmingData {

    using UniswapV2Library for *;
    using SafeERC20 for IERC20;
    using SafeMath for uint;

    function getFeesByToken(address token) public view returns (uint16);

    /**
     * @return The amount of `token` paid for the burn.
     */
    function _payHarvestFee(
        address user,
        address token,
        uint tokenAmount
    ) internal returns (uint) {
        uint fees = getFeesByToken(token);
        if (fees > 0) {
            uint tokenFeeAmount = tokenAmount.mul(fees).div(uint(FEE_AMOUNT_FACTOR));
            DMGYieldFarmingV2Lib.TokenType tokenType = _tokenToTokenType[token];
            require(
                tokenType != DMGYieldFarmingV2Lib.TokenType.Unknown,
                "DMGYieldFarmingV2::_payHarvestFee: UNKNOWN_TOKEN_TYPE"
            );

            if (tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapLpToken) {
                _payFeesWithUniswapToken(user, token, tokenFeeAmount);
            } else {
                revert("DMGYieldFarmingV2::_payHarvestFee UNCAUGHT_TOKEN_TYPE");
            }

            return tokenFeeAmount;
        } else {
            return 0;
        }
    }

    function _payFeesWithUniswapToken(
        address user,
        address token,
        uint tokenFeeAmount
    ) internal {
        address underlyingToken = _tokenToUnderlyingTokenMap[token];

        address tokenToSwap;
        address token0;
        uint amountToBurn;
        uint amountToSwap;
        {
            // New context - to prevent the stack too deep error
            IERC20(token).safeTransfer(token, tokenFeeAmount);
            (uint amount0, uint amount1) = IUniswapV2Pair(token).burn(address(this));
            token0 = IUniswapV2Pair(token).token0();
            address token1 = IUniswapV2Pair(token).token1();

            tokenToSwap = token0 == underlyingToken ? token1 : token0;

            amountToBurn = token0 == underlyingToken ? amount0 : amount1;
            amountToSwap = token1 == underlyingToken ? amount0 : amount1;
        }

        address dmgToken = _dmgToken;

        if (tokenToSwap != dmgToken) {
            IERC20(tokenToSwap).safeTransfer(token, amountToSwap);
            (uint reserve0, uint reserve1,) = IUniswapV2Pair(token).getReserves();
            uint amountOut = UniswapV2Library.getAmountOut(
                amountToSwap,
                tokenToSwap == token0 ? reserve0 : reserve1,
                tokenToSwap != token0 ? reserve0 : reserve1
            );
            (uint amount0Out, uint amount1Out) = tokenToSwap == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            IUniswapV2Pair(token).swap(amount0Out, amount1Out, address(this), new bytes(0));
            amountToBurn = amountToBurn.add(amountOut);
        }

        address weth = _weth;
        uint dmgToBurn = _swapTokensForDmgViaUniswap(amountToBurn, underlyingToken, weth, dmgToken);

        if (tokenToSwap == dmgToken) {
            amountToSwap = amountToSwap.add(dmgToBurn);
            IDMGToken(dmgToken).burn(amountToSwap);
            emit HarvestFeePaid(user, token, tokenFeeAmount, amountToSwap);
        } else {
            IDMGToken(dmgToken).burn(dmgToBurn);
            emit HarvestFeePaid(user, token, tokenFeeAmount, dmgToBurn);
        }
    }

    /**
     * @return  The amount of DMG received from the swap
     */
    function _swapTokensForDmgViaUniswap(
        uint amountToBurn,
        address underlyingToken,
        address weth,
        address dmgToken
    ) internal returns (uint) {
        address[] memory paths;
        if (underlyingToken == weth) {
            paths = new address[](2);
            paths[0] = weth;
            paths[1] = dmgToken;
        } else {
            paths = new address[](3);
            paths[0] = underlyingToken;
            paths[1] = weth;
            paths[2] = dmgToken;
        }
        // We sell the non-mToken to DMG and burn it.
        uint[] memory amountsOut = IUniswapV2Router02(_uniswapV2Router).swapExactTokensForTokens(
            amountToBurn,
        /* amountOutMin */ 1,
            paths,
            address(this),
            block.timestamp
        );

        return amountsOut[amountsOut.length - 1];
    }

}