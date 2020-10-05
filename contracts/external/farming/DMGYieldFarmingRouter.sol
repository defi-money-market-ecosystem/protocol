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

import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../../protocol/interfaces/IWETH.sol";
import "../../utils/AddressUtil.sol";

import "../uniswap/libs/UniswapV2Library.sol";

import "./v1/IDMGYieldFarmingV1.sol";

/**
 * This file is heavily based on Uniswap's V2 Router, because it wraps the user's tokens into LP tokens for them before
 * depositing them into the Yield Farming Protocol contract.
 *
 * https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/UniswapV2Router02.sol
 */
contract DMGYieldFarmingRouter is Ownable, ReentrancyGuard {

    using AddressUtil for address payable;
    using SafeERC20 for IERC20;
    using UniswapV2Library for *;

    address public dmgYieldFarming;
    address public uniswapV2Factory;
    address public weth;
    bytes32 public initCodeHash;

    // Used to prevent stack too deep errors.
    struct UniswapParams {
        address tokenA;
        address tokenB;
        uint liquidity;
        uint amountAMin;
        uint amountBMin;
    }

    modifier ensureDeadline(uint __deadline) {
        require(__deadline >= block.timestamp, "DMGYieldFarmingFundingProxy: EXPIRED");
        _;
    }

    modifier ensurePairIsSupported(address __tokenA, address __tokenB) {
        require(
            IDMGYieldFarmingV1(dmgYieldFarming).isSupportedToken(UniswapV2Library.pairFor(uniswapV2Factory, __tokenA, __tokenB, initCodeHash)),
            "DMGYieldFarmingFundingProxy: TOKEN_UNSUPPORTED"
        );
        _;
    }

    constructor(
        address __dmgYieldFarming,
        address __uniswapV2Factory,
        address __weth,
        bytes32 __initCodeHash
    ) public {
        dmgYieldFarming = __dmgYieldFarming;
        uniswapV2Factory = __uniswapV2Factory;
        weth = __weth;
        initCodeHash = __initCodeHash;
    }

    function() external payable {
        require(
            msg.sender == weth,
            "DMGYieldFarmingFundingProxy::default: INVALID_SENDER"
        );
    }

    function getPair(
        address __tokenA,
        address __tokenB
    ) public view returns (address) {
        return UniswapV2Library.pairFor(uniswapV2Factory, __tokenA, __tokenB, initCodeHash);
    }

    function setInitCodeHash(
        bytes32 __initCodeHash
    )
    public
    onlyOwner {
        initCodeHash = __initCodeHash;
    }

    function enableTokens(
        address[] calldata __tokens,
        address[] calldata __spenders
    )
    external
    nonReentrant {
        require(
            __tokens.length == __spenders.length,
            "DMGYieldFarmingFundingProxy::enableTokens: INVALID_LENGTH"
        );

        for (uint i = 0; i < __tokens.length; i++) {
            IERC20(__tokens[i]).safeApprove(__spenders[i], uint(- 1));
        }
    }

    function addLiquidity(
        address __tokenA,
        address __tokenB,
        uint __amountADesired,
        uint __amountBDesired,
        uint __amountAMin,
        uint __amountBMin,
        uint __deadline
    )
    public
    nonReentrant
    ensureDeadline(__deadline) {
        _verifyTokensAreSupported(__tokenA, __tokenB);

        address _uniswapV2Factory = uniswapV2Factory;

        UniswapParams memory params = UniswapParams({
        tokenA : __tokenA,
        tokenB : __tokenB,
        liquidity : 0,
        amountAMin : __amountAMin,
        amountBMin : __amountBMin
        });

        (uint amountA, uint amountB) = _getAmounts(
            params,
            __amountADesired,
            __amountBDesired,
            _uniswapV2Factory
        );

        address pair = UniswapV2Library.pairFor(uniswapV2Factory, params.tokenA, params.tokenB, initCodeHash);
        uint liquidity = _doTokenTransfersAndMintLiquidity(params, pair, amountA, amountB);

        IDMGYieldFarmingV1(dmgYieldFarming).beginFarming(msg.sender, address(this), pair, liquidity);
    }

    function addLiquidityETH(
        address __token,
        uint __amountTokenDesired,
        uint __amountTokenMin,
        uint __amountETHMin,
        uint __deadline
    )
    public payable
    nonReentrant
    ensureDeadline(__deadline) {
        UniswapParams memory params = UniswapParams({
        tokenA : __token,
        tokenB : weth,
        liquidity : 0,
        amountAMin : __amountTokenMin,
        amountBMin : __amountETHMin
        });

        _verifyTokensAreSupported(__token, params.tokenB);

        address _uniswapV2Factory = uniswapV2Factory;

        (uint amountToken, uint amountETH) = _getAmounts(
            params,
            __amountTokenDesired,
            msg.value,
            _uniswapV2Factory
        );

        address pair = UniswapV2Library.pairFor(_uniswapV2Factory, __token, params.tokenB, initCodeHash);

        uint liquidity = _doTokenTransfersWithEthAndMintLiquidity(params, pair, amountToken, amountETH);

        // refund dust eth, if any
        if (msg.value > amountETH) {
            require(
                msg.sender.sendETH(msg.value - amountETH),
                "DMGYieldFarmingFundingProxy::addLiquidityETH: ETH_TRANSFER_FAILURE"
            );
        }

        IDMGYieldFarmingV1(dmgYieldFarming).beginFarming(msg.sender, address(this), pair, liquidity);
    }

    function removeLiquidity(
        address __tokenA,
        address __tokenB,
        uint __liquidity,
        uint __amountAMin,
        uint __amountBMin,
        uint __deadline,
        bool __isInSeason
    )
    public
    nonReentrant
    ensureDeadline(__deadline) {
        _verifyTokensAreSupported(__tokenA, __tokenB);

        UniswapParams memory params = UniswapParams({
        tokenA : __tokenA,
        tokenB : __tokenB,
        liquidity : __liquidity,
        amountAMin : __amountAMin,
        amountBMin : __amountBMin
        });

        _removeLiquidity(params, msg.sender, msg.sender, __isInSeason);
    }

    function removeLiquidityETH(
        address __token,
        uint __liquidity,
        uint __amountTokenMin,
        uint __amountETHMin,
        uint __deadline,
        bool __isInSeason
    )
    public
    nonReentrant
    ensureDeadline(__deadline) {
        UniswapParams memory params = UniswapParams({
        tokenA : __token,
        tokenB : weth,
        liquidity : __liquidity,
        amountAMin : __amountTokenMin,
        amountBMin : __amountETHMin
        });

        _verifyTokensAreSupported(params.tokenA, params.tokenB);

        (uint amountToken, uint amountETH) = _removeLiquidity(params, msg.sender, address(this), __isInSeason);

        IERC20(params.tokenA).safeTransfer(msg.sender, amountToken);
        IWETH(params.tokenB).withdraw(amountETH);
        require(
            msg.sender.sendETH(amountETH),
            "DMGYieldFarmingFundingProxy::addLiquidityETH: ETH_TRANSFER_FAILURE"
        );
    }

    function _verifyTokensAreSupported(
        address __tokenA,
        address __tokenB
    ) internal view {
        require(
            IDMGYieldFarmingV1(dmgYieldFarming).isSupportedToken(UniswapV2Library.pairFor(uniswapV2Factory, __tokenA, __tokenB, initCodeHash)),
            "DMGYieldFarmingFundingProxy::_verifyTokensAreSupported: TOKEN_UNSUPPORTED"
        );
    }

    function _removeLiquidity(
        UniswapParams memory __params,
        address __farmer,
        address __liquidityRecipient,
        bool __isInSeason
    )
    internal returns (uint amountA, uint amountB) {
        address pair = UniswapV2Library.pairFor(uniswapV2Factory, __params.tokenA, __params.tokenB, initCodeHash);
        uint liquidity;
        if (__isInSeason) {
            (uint _liquidity, uint dmgEarned) = IDMGYieldFarmingV1(dmgYieldFarming).endFarmingByToken(__farmer, address(this), pair);
            liquidity = _liquidity;
            // Forward the DMG along to the farmer
            IERC20(IDMGYieldFarmingV1(dmgYieldFarming).dmgToken()).safeTransfer(__farmer, dmgEarned);
        } else {
            liquidity = IDMGYieldFarmingV1(dmgYieldFarming).withdrawByTokenWhenOutOfSeason(
                __farmer,
                address(this),
                pair
            );
        }

        IERC20(pair).safeTransfer(pair, liquidity);
        (uint amount0, uint amount1) = IUniswapV2Pair(pair).burn(__liquidityRecipient);
        (address token0,) = UniswapV2Library.sortTokens(__params.tokenA, __params.tokenB);
        (amountA, amountB) = __params.tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        require(amountA >= __params.amountAMin, 'DMGYieldFarmingFundingProxy::removeLiquidity: INSUFFICIENT_A_AMOUNT');
        require(amountB >= __params.amountBMin, 'DMGYieldFarmingFundingProxy::removeLiquidity: INSUFFICIENT_B_AMOUNT');
    }

    /// This function is based on UniswapV2Router02.sol:
    /// https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L33
    function _getAmounts(
        UniswapParams memory __params,
        uint __amountADesired,
        uint __amountBDesired,
        address __uniswapV2Factory
    )
    internal view returns (uint amountA, uint amountB) {
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(__uniswapV2Factory, __params.tokenA, __params.tokenB, initCodeHash);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (__amountADesired, __amountBDesired);
        } else {
            uint amountBOptimal = UniswapV2Library.quote(__amountADesired, reserveA, reserveB);
            if (amountBOptimal <= __amountBDesired) {
                require(
                    amountBOptimal >= __params.amountBMin,
                    "DMGYieldFarmingFundingProxy::_getAmounts: INSUFFICIENT_B_AMOUNT"
                );

                (amountA, amountB) = (__amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = UniswapV2Library.quote(__amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= __amountADesired);
                require(
                    amountAOptimal >= __params.amountAMin,
                    "DMGYieldFarmingFundingProxy::_getAmounts: INSUFFICIENT_A_AMOUNT"
                );

                (amountA, amountB) = (amountAOptimal, __amountBDesired);
            }
        }
    }

    function _doTokenTransfersAndMintLiquidity(
        UniswapParams memory __params,
        address __pair,
        uint __amountA,
        uint __amountB
    ) internal returns (uint) {
        IERC20(__params.tokenA).safeTransferFrom(msg.sender, __pair, __amountA);
        IERC20(__params.tokenB).safeTransferFrom(msg.sender, __pair, __amountB);

        return IUniswapV2Pair(__pair).mint(address(this));
    }

    function _doTokenTransfersWithEthAndMintLiquidity(
        UniswapParams memory __params,
        address __pair,
        uint __amountToken,
        uint __amountETH
    ) internal returns (uint) {
        IERC20(__params.tokenA).safeTransferFrom(msg.sender, __pair, __amountToken);
        IWETH(__params.tokenB).deposit.value(__amountETH)();
        IERC20(__params.tokenB).safeTransfer(__pair, __amountETH);

        return IUniswapV2Pair(__pair).mint(address(this));
    }

}