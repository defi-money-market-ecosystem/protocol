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

import "../../protocol/interfaces/IWETH.sol";
import "../../utils/AddressUtil.sol";

import "./libs/UniswapV2Library.sol";

import "./v1/IDMGYieldFarmingV1.sol";

contract DMGYieldFarmingFundingProxy is Ownable {

    // TODO DELETE
    function toString(bytes memory value) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + (value.length * 2));
        str[0] = '0';
        str[1] = 'x';
        for (uint i = 0; i < value.length; i++) {
            str[2 + i * 2] = alphabet[uint(uint8(value[i] >> 4))];
            str[3 + i * 2] = alphabet[uint(uint8(value[i] & 0x0f))];
        }
        return string(str);
    }

    using AddressUtil for address payable;
    using SafeERC20 for IERC20;
    using UniswapV2Library for *;

    address public dmgYieldFarming;
    address public uniswapV2Factory;
    address public weth;

    // Used to prevent stack too deep errors.
    struct UniswapParams {
        address tokenA;
        address tokenB;
        uint liquidity;
        uint amountAMin;
        uint amountBMin;
    }

    modifier ensureDeadline(uint deadline) {
        require(deadline >= block.timestamp, "DMGYieldFarmingFundingProxy: EXPIRED");
        _;
    }

    modifier ensurePairIsSupported(address tokenA, address tokenB) {
        require(
            IDMGYieldFarmingV1(dmgYieldFarming).isSupportedToken(UniswapV2Library.pairFor(uniswapV2Factory, tokenA, tokenB)),
            "DMGYieldFarmingFundingProxy: TOKEN_UNSUPPORTED"
        );
        _;
    }

    constructor(
        address _dmgYieldFarming,
        address _uniswapV2Factory,
        address _weth
    ) public {
        dmgYieldFarming = _dmgYieldFarming;
        uniswapV2Factory = _uniswapV2Factory;
        weth = _weth;
    }

    function() external payable {
        require(
            msg.sender == weth,
            "DMGYieldFarmingFundingProxy::default: INVALID_SENDER"
        );
    }

    function getPair(
        address tokenA,
        address tokenB
    ) public view returns (address) {
        return UniswapV2Library.pairFor(uniswapV2Factory, tokenA, tokenB);
    }

    function enableTokens(
        address[] calldata tokens,
        address[] calldata spenders
    )
    external
    onlyOwner {
        require(
            tokens.length == spenders.length,
            "DMGYieldFarmingFundingProxy::enableTokens: INVALID_LENGTH"
        );

        for (uint i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeApprove(spenders[i], uint(- 1));
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        uint deadline
    )
    public
    ensureDeadline(deadline) {
        _verifyTokensAreSupported(tokenA, tokenB);

        address _uniswapV2Factory = uniswapV2Factory;
        (uint amountA, uint amountB) = _getAmounts(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            _uniswapV2Factory
        );

        address pair = UniswapV2Library.pairFor(_uniswapV2Factory, tokenA, tokenB);

        IERC20(tokenA).safeTransferFrom(msg.sender, pair, amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, pair, amountB);

        uint liquidity = IUniswapV2Pair(pair).mint(address(this));

        IDMGYieldFarmingV1(dmgYieldFarming).beginFarming(msg.sender, address(this), pair, liquidity);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline
    )
    public payable
    ensureDeadline(deadline) {
        address _weth = weth;
        _verifyTokensAreSupported(token, _weth);

        address _uniswapV2Factory = uniswapV2Factory;
        (uint amountToken, uint amountETH) = _getAmounts(
            token,
            _weth,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin,
            _uniswapV2Factory
        );

        address pair = UniswapV2Library.pairFor(_uniswapV2Factory, token, _weth);

        IERC20(token).safeTransferFrom(msg.sender, pair, amountToken);
        IWETH(_weth).deposit.value(amountETH)();
        IERC20(_weth).safeTransfer(pair, amountETH);

        uint liquidity = IUniswapV2Pair(pair).mint(address(this));

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
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        uint deadline,
        bool isInSeason
    )
    public
    ensureDeadline(deadline) {
        _verifyTokensAreSupported(tokenA, tokenB);

        UniswapParams memory params = UniswapParams({
        tokenA : tokenA,
        tokenB : tokenB,
        liquidity : liquidity,
        amountAMin : amountAMin,
        amountBMin : amountBMin
        });

        _removeLiquidity(params, msg.sender, msg.sender, isInSeason);
    }

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        uint deadline,
        bool isInSeason
    )
    public
    ensureDeadline(deadline) {
        UniswapParams memory params = UniswapParams({
        tokenA : token,
        tokenB : weth,
        liquidity : liquidity,
        amountAMin : amountTokenMin,
        amountBMin : amountETHMin
        });

        _verifyTokensAreSupported(params.tokenA, params.tokenB);

        (uint amountToken, uint amountETH) = _removeLiquidity(params, msg.sender, address(this), isInSeason);

        IERC20(params.tokenA).safeTransfer(msg.sender, amountToken);
        IWETH(params.tokenB).withdraw(amountETH);
        require(
            msg.sender.sendETH(amountETH),
            "DMGYieldFarmingFundingProxy::addLiquidityETH: ETH_TRANSFER_FAILURE"
        );
    }

    function _verifyTokensAreSupported(
        address tokenA,
        address tokenB
    ) internal view {
        require(
            IDMGYieldFarmingV1(dmgYieldFarming).isSupportedToken(UniswapV2Library.pairFor(uniswapV2Factory, tokenA, tokenB)),
            "DMGYieldFarmingFundingProxy::_verifyTokensAreSupported: TOKEN_UNSUPPORTED"
        );
    }

    function _removeLiquidity(
        UniswapParams memory params,
        address farmer,
        address liquidityRecipient,
        bool isInSeason
    )
    internal returns (uint amountA, uint amountB) {
        address pair = UniswapV2Library.pairFor(uniswapV2Factory, params.tokenA, params.tokenB);
        uint liquidity;
        if (isInSeason) {
            (uint _liquidity, uint dmgEarned) = IDMGYieldFarmingV1(dmgYieldFarming).endFarmingByToken(farmer, address(this), pair);
            liquidity = _liquidity;
            // Forward the DMG along to the farmer
            IERC20(IDMGYieldFarmingV1(dmgYieldFarming).dmgToken()).safeTransfer(farmer, dmgEarned);
        } else {
            liquidity = IDMGYieldFarmingV1(dmgYieldFarming).withdrawByTokenWhenOutOfSeason(
                farmer,
                address(this),
                pair
            );
        }

        IERC20(pair).safeTransfer(pair, liquidity);
        (uint amount0, uint amount1) = IUniswapV2Pair(pair).burn(liquidityRecipient);
        (address token0,) = UniswapV2Library.sortTokens(params.tokenA, params.tokenB);
        (amountA, amountB) = params.tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        require(amountA >= params.amountAMin, 'DMGYieldFarmingFundingProxy::removeLiquidity: INSUFFICIENT_A_AMOUNT');
        require(amountB >= params.amountBMin, 'DMGYieldFarmingFundingProxy::removeLiquidity: INSUFFICIENT_B_AMOUNT');
    }

    function _getAmounts(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address uniswapV2Factory
    )
    internal view returns (uint amountA, uint amountB) {
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(uniswapV2Factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'DMGYieldFarmingFundingProxy::_getAmounts: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'DMGYieldFarmingFundingProxy::_getAmounts: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

}