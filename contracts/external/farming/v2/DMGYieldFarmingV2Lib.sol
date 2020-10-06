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
import "../../../utils/IERC20WithDecimals.sol";

import "../DMGYieldFarmingData.sol";

import "./IDMGYieldFarmingV2.sol";

library DMGYieldFarmingV2Lib {

    using SafeMath for uint;
    using SafeERC20 for IERC20;
    using UniswapV2Library for *;

    // ////////////////////
    // Enums
    // ////////////////////

    enum TokenType {
        Unknown,
        UniswapLpToken
    }

    // ////////////////////
    // Events
    // ////////////////////

    /**
     * @param tokenAmountToConvert  The amount of `token` to be converted to DMG and burned.
     * @param dmgAmountBurned       The amount of DMG burned after `tokenAmountToConvert` was converted to DMG.
     */
    event HarvestFeePaid(address indexed owner, address indexed token, uint tokenAmountToConvert, uint dmgAmountBurned);

    // ////////////////////
    // Functions
    // ////////////////////

    /**
     * @return The amount of `__token` paid for the burn.
     */
    function _payHarvestFee(
        IDMGYieldFarmingV2 state,
        address __user,
        address __token,
        uint __tokenAmount
    ) public returns (uint) {
        uint fees = state.getFeesByToken(__token);
        if (fees > 0) {
            uint tokenFeeAmount = __tokenAmount.mul(fees).div(uint(DMGYieldFarmingData(address(state)).FEE_AMOUNT_FACTOR()));
            require(
                tokenFeeAmount > 0,
                "DMGYieldFarmingV2Lib::_payHarvestFee: TOKEN_AMOUNT_TOO_SMALL_FOR_FEE"
            );

            DMGYieldFarmingV2Lib.TokenType tokenType = state.getTokenTypeByToken(__token);
            require(
                tokenType != DMGYieldFarmingV2Lib.TokenType.Unknown,
                "DMGYieldFarmingV2Lib::_payHarvestFee: UNKNOWN_TOKEN_TYPE"
            );

            if (tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapLpToken) {
                _payFeesWithUniswapToken(
                    state,
                    __user,
                    __token,
                    tokenFeeAmount,
                    state.getUnderlyingTokenByFarmToken(__token)
                );
            } else {
                revert(
                    "DMGYieldFarmingV2Lib::_payHarvestFee UNCAUGHT_TOKEN_TYPE"
                );
            }

            return tokenFeeAmount;
        } else {
            return 0;
        }
    }

    function _payFeesWithUniswapToken(
        IDMGYieldFarmingV2 state,
        address __user,
        address __token,
        uint __tokenFeeAmount,
        address underlyingToken
    ) public {

        // This is the __token that is NOT the underlyingToken. Meaning, it needs to be converted to underlyingToken so
        // it can be swapped to DMG and burned.
        address tokenToSwap;
        address token0;
        uint amountToBurn;
        uint amountToSwap;
        {
            // New context - to prevent the stack too deep error
            // --------------------------------------------------
            // This code is taken from the `UniswapV2Router02` to more efficiently convert the LP __token *TO* its
            // reserve tokens
            IERC20(__token).safeTransfer(__token, __tokenFeeAmount);
            (uint amount0, uint amount1) = IUniswapV2Pair(__token).burn(address(this));
            token0 = IUniswapV2Pair(__token).token0();

            tokenToSwap = token0 == underlyingToken ? IUniswapV2Pair(__token).token1() : token0;

            amountToBurn = token0 == underlyingToken ? amount0 : amount1;
            amountToSwap = token0 != underlyingToken ? amount0 : amount1;
        }

        address dmg = state.dmgToken();
        if (tokenToSwap != dmg) {
            // This code is taken from the `UniswapV2Router02` to more efficiently swap *TO* the underlying __token
            IERC20(tokenToSwap).safeTransfer(__token, amountToSwap);
            (uint reserve0, uint reserve1,) = IUniswapV2Pair(__token).getReserves();
            uint amountOut = UniswapV2Library.getAmountOut(
                amountToSwap,
                tokenToSwap == token0 ? reserve0 : reserve1,
                tokenToSwap != token0 ? reserve0 : reserve1
            );

            (uint amount0Out, uint amount1Out) = tokenToSwap == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            IUniswapV2Pair(__token).swap(amount0Out, amount1Out, address(this), new bytes(0));

            amountToBurn = amountToBurn.add(amountOut);
        }

        uint dmgToBurn = _swapTokensForDmgViaUniswap(state, amountToBurn, underlyingToken, state.weth(), dmg);

        if (tokenToSwap == dmg) {
            // We can just add the DMG to be swapped with the amount to burn.
            amountToSwap = amountToSwap.add(dmgToBurn);
            IDMGToken(dmg).burn(amountToSwap);
            emit HarvestFeePaid(__user, __token, __tokenFeeAmount, amountToSwap);
        } else {
            IDMGToken(dmg).burn(dmgToBurn);
            emit HarvestFeePaid(__user, __token, __tokenFeeAmount, dmgToBurn);
        }
    }

    /**
     * @return  The amount of DMG received from the swap
     */
    function _swapTokensForDmgViaUniswap(
        IDMGYieldFarmingV2 state,
        uint __amountToBurn,
        address __underlyingToken,
        address __weth,
        address __dmg
    ) public returns (uint) {
        address[] memory paths;
        if (__underlyingToken == __weth) {
            paths = new address[](2);
            paths[0] = __weth;
            paths[1] = __dmg;
        } else {
            paths = new address[](3);
            paths[0] = __underlyingToken;
            paths[1] = __weth;
            paths[2] = __dmg;
        }
        // We sell the non-mToken to DMG and burn it.
        uint[] memory amountsOut = IUniswapV2Router02(state.uniswapV2Router()).swapExactTokensForTokens(
            __amountToBurn,
        /* amountOutMin */ 1,
            paths,
            address(this),
            block.timestamp
        );

        return amountsOut[amountsOut.length - 1];
    }

}