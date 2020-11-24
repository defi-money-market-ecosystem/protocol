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
import "../../../protocol/interfaces/IDmmController.sol";
import "../../../protocol/interfaces/IUnderlyingTokenValuator.sol";
import "../../../utils/IERC20WithDecimals.sol";

import "../DMGYieldFarmingData.sol";

import "./IDMGYieldFarmingV2.sol";

library DMGYieldFarmingV2Lib {

    using SafeMath for uint;
    using SafeERC20 for IERC20;
    using UniswapV2Library for *;

    uint constant private ONE_WEI = 1e18;

    // ////////////////////
    // Enums
    // ////////////////////

    enum TokenType {
        Unknown,
        UniswapLpToken,
        UniswapPureLpToken // Does not have an mToken base pairing. IE DMG-ETH
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
     * @return  The dollar value of `tokenAmount`, formatted as a number with 18 decimal places
     */
    function _getUsdValueByTokenAndTokenAmount(
        IDMGYieldFarmingV2 state,
        address __farmToken,
        uint __tokenAmount
    ) public view returns (uint) {
        address underlyingToken = state.getUnderlyingTokenByFarmToken(__farmToken);
        address __underlyingTokenValuator = state.underlyingTokenValuator();
        DMGYieldFarmingV2Lib.TokenType tokenType = state.getTokenTypeByToken(__farmToken);

        if (tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapLpToken) {
            return _getUsdValueByTokenAndAmountForUniswapLpToken(
                __farmToken,
                __tokenAmount,
                underlyingToken,
                state.getTokenDecimalsByToken(__farmToken),
                state.dmmController(),
                __underlyingTokenValuator
            );
        } else if (tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapPureLpToken) {
            uint8 underlyingTokenDecimals = state.getTokenDecimalsByToken(__farmToken);
            (address otherToken, uint underlyingTokenReserveAmount, uint otherTokenReserveAmount) = _getUniswapParams(
                __farmToken,
                underlyingToken,
                underlyingTokenDecimals,
                __underlyingTokenValuator,
                address(0)
            );
            uint8 otherTokenDecimals = IERC20WithDecimals(otherToken).decimals();

            uint totalSupply = IERC20(__farmToken).totalSupply();
            require(
                totalSupply > 0,
                "DMGYieldFarmingV2::_getUsdValueByTokenAndTokenAmount: INVALID_TOTAL_SUPPLY"
            );

            uint underlyingTokenUsdValue = _getUnderlyingTokenUsdValueFromUniswapPool(
                __tokenAmount,
                totalSupply,
                underlyingToken,
                underlyingTokenReserveAmount,
                underlyingTokenDecimals,
                __underlyingTokenValuator
            );

            uint otherTokenUsdValue = _getUnderlyingTokenUsdValueFromUniswapPool(
                __tokenAmount,
                totalSupply,
                otherToken,
                otherTokenReserveAmount,
                otherTokenDecimals,
                __underlyingTokenValuator
            );

            return underlyingTokenUsdValue.add(otherTokenUsdValue);
        } else {
            revert("DMGYieldFarmingV2::_getUsdValueByTokenAndTokenAmount: INVALID_TOKEN_TYPE");
        }
    }

    function _getUsdValueByTokenAndAmountForUniswapLpToken(
        address __farmToken,
        uint __farmTokenAmount,
        address __underlyingToken,
        uint8 __underlyingTokenDecimals,
        address __dmmController,
        address __underlyingTokenValuator
    ) internal view returns (uint) {
        (address mToken, uint underlyingTokenAmount, uint mTokenAmount) = _getUniswapParams(
            __farmToken,
            __underlyingToken,
            __underlyingTokenDecimals,
            __underlyingTokenValuator,
            __dmmController
        );
        uint8 mTokenDecimals = IERC20WithDecimals(mToken).decimals();

        uint totalSupply = IERC20(__farmToken).totalSupply();
        require(
            totalSupply > 0,
            "DMGYieldFarmingV2::_getUsdValueByTokenAndTokenAmount: INVALID_TOTAL_SUPPLY"
        );

        uint underlyingTokenUsdValue = _getUnderlyingTokenUsdValueFromUniswapPool(
            __farmTokenAmount,
            totalSupply,
            __underlyingToken,
            underlyingTokenAmount,
            __underlyingTokenDecimals,
            __underlyingTokenValuator
        );

        uint mTokenUsdValue = _getMTokenUsdValueFromUniswapPool(
            __farmTokenAmount,
            totalSupply,
            mToken,
            mTokenAmount,
            mTokenDecimals,
            __dmmController,
            __underlyingTokenValuator
        );

        return underlyingTokenUsdValue.add(mTokenUsdValue);
    }

    function _getUniswapParams(
        address __farmToken,
        address __underlyingToken,
        uint8 __underlyingTokenDecimals,
        address __underlyingTokenValuator,
        address __dmmController
    ) public view returns (address otherToken, uint underlyingTokenAmount, uint otherTokenAmount) {
        address token0 = IUniswapV2Pair(__farmToken).token0();
        address token1 = IUniswapV2Pair(__farmToken).token1();

        require(
            __underlyingToken == token0 || __underlyingToken == token1,
            "DMGYieldFarmingV2Lib::_getUniswapParams: INVALID_UNDERLYING"
        );

        otherToken = __underlyingToken == token0 ? token1 : token0;

        {
            (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(__farmToken).getReserves();
            underlyingTokenAmount = __underlyingToken == token0 ? reserve0 : reserve1;
            otherTokenAmount = __underlyingToken == token0 ? reserve1 : reserve0;
        }

        {
            (uint newUnderlyingAmount, uint newOtherAmount) = _scaleUniswapPriceBasedOnOraclePrice(
                __underlyingToken,
                __underlyingTokenDecimals,
                underlyingTokenAmount,
                otherToken,
                IERC20WithDecimals(otherToken).decimals(),
                otherTokenAmount,
                IUnderlyingTokenValuator(__underlyingTokenValuator),
                IDmmController(__dmmController)
            );

            underlyingTokenAmount = newUnderlyingAmount;
            otherTokenAmount = newOtherAmount;
        }
    }

    /**
     * @dev Scales the price (Uniswap reserve ratio) by lowering whichever asset's value is too high to achieve the
     *      appropriate ratio.
     */
    function _scaleUniswapPriceBasedOnOraclePrice(
        address __underlyingToken,
        uint8 __underlyingDecimals,
        uint __underlyingAmount,
        address __otherToken,
        uint8 __otherDecimals,
        uint __otherAmount,
        IUnderlyingTokenValuator __underlyingTokenValuator,
        IDmmController __dmmController
    ) internal view returns (uint, uint) {
        uint foundPrice;
        {
            uint standardizedUnderlyingAmount = _standardizeAmountBasedOnDecimals(__underlyingAmount, __underlyingDecimals);
            uint standardizedOtherAmount = _standardizeAmountBasedOnDecimals(__otherAmount, __otherDecimals);

            // Get the actual value of 1 value of otherToken according to Uniswap --> IE value of 1 DMG or 1 mETH or 1 mUSDC
            foundPrice = __underlyingTokenValuator.getTokenValue(__underlyingToken, standardizedUnderlyingAmount.mul(ONE_WEI).div(standardizedOtherAmount));
        }

        // Get the expected value of other token
        uint expectedPrice;
        if (address(__dmmController) == address(0)) {
            // The __otherToken is not an mToken; we get its value through the usual means
            expectedPrice = __underlyingTokenValuator.getTokenValue(__otherToken, ONE_WEI);
        } else {
            // The __otherToken is an mToken; we must get its value by using its exchange rate against its underlying
            address underlyingForMToken = __dmmController.getUnderlyingTokenForDmm(__otherToken);
            uint exchangeRate = __dmmController.getExchangeRate(__otherToken);
            expectedPrice = __underlyingTokenValuator.getTokenValue(underlyingForMToken, ONE_WEI.mul(exchangeRate).div(ONE_WEI));
        }

        if (foundPrice > expectedPrice) {
            // We need to lower the Uni reserve ratio; we can do this by lowering the numerator == underlyingAmount
            __underlyingAmount = __underlyingAmount.mul(expectedPrice).div(foundPrice);
        } else /* expectedPrice >= foundPrice */ {
            // We need to raise the Uni reserve ratio; we can do this by lowering the denominator == otherAmount
            __otherAmount = __otherAmount.mul(foundPrice).div(expectedPrice);
        }

        return (__underlyingAmount, __otherAmount);
    }

    function _getUnderlyingTokenUsdValueFromUniswapPool(
        uint __tokenAmount,
        uint __totalSupply,
        address __underlyingToken,
        uint __underlyingTokenReserveAmount,
        uint8 __underlyingTokenDecimals,
        address __underlyingTokenValuator
    ) public view returns (uint) {
        uint underlyingTokenAmount = __tokenAmount
        .mul(__underlyingTokenReserveAmount)
        .div(__totalSupply);

        return _getUsdValueForUnderlyingTokenAmount(
            __underlyingToken,
            __underlyingTokenValuator,
            __underlyingTokenDecimals,
            underlyingTokenAmount
        );
    }

    function _getMTokenUsdValueFromUniswapPool(
        uint __tokenAmount,
        uint __totalSupply,
        address __mToken,
        uint __mTokenReserveAmount,
        uint8 __mTokenDecimals,
        address __dmmController,
        address __underlyingTokenValuator
    ) public view returns (uint) {
        uint mTokenAmount = __tokenAmount
        .mul(__mTokenReserveAmount)
        .div(__totalSupply);

        // The exchange rate always has 18 decimals.
        return _getUsdValueForUnderlyingTokenAmount(
            IDmmController(__dmmController).getUnderlyingTokenForDmm(__mToken),
            __underlyingTokenValuator,
            __mTokenDecimals,
            mTokenAmount.mul(IDmmController(__dmmController).getExchangeRate(__mToken)).div(1e18)
        );
    }

    function _getUsdValueForUnderlyingTokenAmount(
        address __underlyingToken,
        address __underlyingTokenValuator,
        uint8 __decimals,
        uint __amount
    ) public view returns (uint) {
        __amount = _standardizeAmountBasedOnDecimals(__amount, __decimals);
        return IUnderlyingTokenValuator(__underlyingTokenValuator).getTokenValue(__underlyingToken, __amount);
    }

    function _standardizeAmountBasedOnDecimals(
        uint __amount,
        uint8 __decimals
    ) internal pure returns (uint) {
        if (__decimals < 18) {
            return __amount.mul((10 ** (18 - uint(__decimals))));
        } else if (__decimals > 18) {
            return __amount.div((10 ** (uint(__decimals) - 18)));
        } else {
            return __amount;
        }
    }

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

            if (tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapLpToken ||
                tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapPureLpToken) {
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
        address __uniswapToken,
        uint __tokenFeeAmount,
        address underlyingToken
    ) public {

        // This is the token that is NOT the underlyingToken. Meaning, it needs to be converted to underlyingToken so
        // it can be added to underlyingToken amount, swapped (as underlyingToken) to DMG, and burned.
        address tokenToSwap;
        address token0;
        uint amountToBurn;
        uint amountToSwap;
        {
            // New context - to prevent the stack too deep error
            // --------------------------------------------------
            // This code is taken from the `UniswapV2Router02` to more efficiently convert the LP __token *TO* its
            // reserve tokens
            IERC20(__uniswapToken).safeTransfer(__uniswapToken, __tokenFeeAmount);
            (uint amount0, uint amount1) = IUniswapV2Pair(__uniswapToken).burn(address(this));
            token0 = IUniswapV2Pair(__uniswapToken).token0();

            tokenToSwap = token0 == underlyingToken ? IUniswapV2Pair(__uniswapToken).token1() : token0;

            amountToBurn = token0 == underlyingToken ? amount0 : amount1;
            amountToSwap = token0 != underlyingToken ? amount0 : amount1;
        }

        address dmg = state.dmgToken();
        if (tokenToSwap != dmg) {
            // Exchanges `tokenToSwap` to `underlyingToken`, so `underlyingToken` can be swapped to DMG and burned.
            // This code is taken from the `UniswapV2Router02` to more efficiently swap *TO* the underlying __token
            IERC20(tokenToSwap).safeTransfer(__uniswapToken, amountToSwap);
            (uint reserve0, uint reserve1,) = IUniswapV2Pair(__uniswapToken).getReserves();
            uint amountOut = UniswapV2Library.getAmountOut(
                amountToSwap,
                tokenToSwap == token0 ? reserve0 : reserve1,
                tokenToSwap != token0 ? reserve0 : reserve1
            );

            (uint amount0Out, uint amount1Out) = tokenToSwap == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            IUniswapV2Pair(__uniswapToken).swap(amount0Out, amount1Out, address(this), new bytes(0));

            amountToBurn = amountToBurn.add(amountOut);
        }

        uint dmgToBurn = _swapTokensForDmgViaUniswap(state, amountToBurn, underlyingToken, state.weth(), dmg);

        if (tokenToSwap == dmg) {
            // We can just add the DMG to be swapped with the amount to burn.
            amountToSwap = amountToSwap.add(dmgToBurn);
            IDMGToken(dmg).burn(amountToSwap);
            emit HarvestFeePaid(__user, __uniswapToken, __tokenFeeAmount, amountToSwap);
        } else {
            IDMGToken(dmg).burn(dmgToBurn);
            emit HarvestFeePaid(__user, __uniswapToken, __tokenFeeAmount, dmgToBurn);
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
        // We sell the underlyingToken to DMG and burn it.
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