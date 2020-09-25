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
import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../../../governance/dmg/IDMGToken.sol";
import "../../../protocol/interfaces/IDmmController.sol";
import "../../../protocol/interfaces/IUnderlyingTokenValuator.sol";

import "../../uniswap/interfaces/IUniswapV2Pair.sol";
import "../../uniswap/interfaces/IUniswapV2Router02.sol";

import "./IDMGYieldFarmingV2.sol";
import "../DMGYieldFarmingData.sol";
import "../v1/IDMGYieldFarmingV1.sol";
import "../v1/IDMGYieldFarmingV1Initializable.sol";

contract DMGYieldFarmingV2 is IDMGYieldFarmingV2, DMGYieldFarmingData {

    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address constant public ZERO_ADDRESS = address(0);

    modifier isSpenderApproved(address user) {
        require(
            msg.sender == user || _globalProxyToIsTrustedMap[msg.sender] || _userToSpenderToIsApprovedMap[user][msg.sender],
            "DMGYieldFarmingV2: UNAPPROVED"
        );
        _;
    }

    modifier onlyOwnerOrGuardian {
        require(
            msg.sender == _owner || msg.sender == _guardian,
            "DMGYieldFarmingV2: UNAUTHORIZED"
        );
        _;
    }

    modifier farmIsActive {
        require(_isFarmActive, "DMGYieldFarmingV2: FARM_NOT_ACTIVE");
        _;
    }

    modifier requireIsFarmToken(address token) {
        require(_tokenToIndexPlusOneMap[token] != 0, "DMGYieldFarmingV2: TOKEN_UNSUPPORTED");
        _;
    }

    modifier farmIsNotActive {
        require(!_isFarmActive, "DMGYieldFarmingV2: FARM_IS_ACTIVE");
        _;
    }

    // ////////////////////
    // Admin Functions
    // ////////////////////

    function approveGloballyTrustedProxy(
        address proxy,
        bool isTrusted
    )
    public
    nonReentrant
    onlyOwnerOrGuardian {
        _globalProxyToIsTrustedMap[proxy] = isTrusted;
        emit GlobalProxySet(proxy, isTrusted);
    }

    function isGloballyTrustedProxy(
        address proxy
    ) public view returns (bool) {
        return _globalProxyToIsTrustedMap[proxy];
    }

    function addAllowableToken(
        address token,
        address underlyingToken,
        uint8 underlyingTokenDecimals,
        uint16 points,
        uint16 fees,
        DMGYieldFarmingV2Lib.TokenType tokenType
    )
    public
    onlyOwnerOrGuardian
    nonReentrant {
        uint index = _tokenToIndexPlusOneMap[token];
        require(
            index == 0,
            "DMGYieldFarmingV2::addAllowableToken: TOKEN_ALREADY_SUPPORTED"
        );
        _verifyTokenFees(fees);
        _verifyTokenType(tokenType, token, underlyingToken);
        _verifyPoints(points);

        _tokenToIndexPlusOneMap[token] = _supportedFarmTokens.push(token);
        _tokenToRewardPointMap[token] = points;
        _tokenToDecimalsMap[token] = underlyingTokenDecimals;
        _tokenToTokenType[token] = tokenType;
        emit TokenAdded(token, underlyingToken, underlyingTokenDecimals, points, fees);
    }

    function removeAllowableToken(
        address token
    )
    public
    onlyOwnerOrGuardian
    nonReentrant
    farmIsNotActive {
        uint index = _tokenToIndexPlusOneMap[token];
        require(
            index != 0,
            "DMGYieldFarmingV2::removeAllowableToken: TOKEN_NOT_SUPPORTED"
        );
        _tokenToIndexPlusOneMap[token] = 0;
        _tokenToRewardPointMap[token] = 0;
        delete _supportedFarmTokens[index - 1];
        emit TokenRemoved(token);
    }

    function beginFarmingSeason(
        uint dmgAmount
    )
    public
    onlyOwnerOrGuardian
    nonReentrant {
        require(!_isFarmActive, "DMGYieldFarmingV2::beginFarmingSeason: FARM_ALREADY_ACTIVE");

        _seasonIndex += 1;
        _isFarmActive = true;
        address dmgToken = _dmgToken;
        IERC20(dmgToken).safeTransferFrom(msg.sender, address(this), dmgAmount);
        _addressToTokenToBalanceMap[ZERO_ADDRESS][dmgToken] = _addressToTokenToBalanceMap[ZERO_ADDRESS][dmgToken].add(dmgAmount);

        emit FarmSeasonBegun(_seasonIndex, dmgAmount);
    }

    function endActiveFarmingSeason(
        address dustRecipient
    )
    public
    nonReentrant {
        address dmgToken = _dmgToken;
        uint dmgBalance = _getDmgRewardBalance(dmgToken);
        // Anyone can end the farm if the DMG balance has been drawn down to 0.
        require(
            dmgBalance == 0 || msg.sender == owner() || msg.sender == _guardian,
            "DMGYieldFarmingV2::endActiveFarmingSeason: FARM_ACTIVE_OR_INVALID_SENDER"
        );

        _isFarmActive = false;
        if (dmgBalance > 0) {
            IERC20(dmgToken).safeTransfer(dustRecipient, dmgBalance);
        }

        emit FarmSeasonEnd(_seasonIndex, dustRecipient, dmgBalance);
    }

    function setDmgGrowthCoefficient(
        uint dmgGrowthCoefficient
    )
    public
    nonReentrant
    onlyOwnerOrGuardian {
        _verifyDmgGrowthCoefficient(dmgGrowthCoefficient);

        _dmgGrowthCoefficient = dmgGrowthCoefficient;
        emit DmgGrowthCoefficientSet(dmgGrowthCoefficient);
    }

    function setRewardPointsByToken(
        address token,
        uint16 points
    )
    public
    nonReentrant
    onlyOwnerOrGuardian {
        _verifyPoints(points);
        _tokenToRewardPointMap[token] = points;
        emit RewardPointsSet(token, points);
    }

    function setUnderlyingTokenValuator(
        address underlyingTokenValuator
    )
    onlyOwnerOrGuardian
    nonReentrant
    public {
        require(
            underlyingTokenValuator != address(0),
            "DMGYieldFarmingV2::setUnderlyingTokenValuator: INVALID_VALUATOR"
        );
        address oldUnderlyingTokenValuator = _underlyingTokenValuator;
        _underlyingTokenValuator = underlyingTokenValuator;
        emit UnderlyingTokenValuatorChanged(underlyingTokenValuator, oldUnderlyingTokenValuator);
    }

    function setWethToken(
        address weth
    )
    onlyOwnerOrGuardian
    nonReentrant
    public {
        require(
            _weth == address(0),
            "DMGYieldFarmingV2::setWethToken: WETH_ALREADY_SET"
        );
        _weth = weth;
    }

    function setUniswapV2Router(
        address uniswapV2Router
    )
    onlyOwnerOrGuardian
    nonReentrant
    public {
        require(
            uniswapV2Router != address(0),
            "DMGYieldFarmingV2::setUnderlyingTokenValuator: INVALID_VALUATOR"
        );
        address oldUniswapV2Router = _uniswapV2Router;
        _uniswapV2Router = uniswapV2Router;
        emit UniswapV2RouterChanged(uniswapV2Router, oldUniswapV2Router);
    }

    function setFeesByToken(
        address token,
        uint16 fees
    )
    onlyOwnerOrGuardian
    nonReentrant
    requireIsFarmToken(token)
    public {
        _verifyTokenFees(fees);
        _tokenToFeeAmountMap[token] = fees;
        emit FeesChanged(token, fees);
    }

    function setTokenTypeByToken(
        address token,
        DMGYieldFarmingV2Lib.TokenType tokenType
    )
    onlyOwnerOrGuardian
    nonReentrant
    requireIsFarmToken(token)
    public {
        _verifyTokenType(tokenType, token, _tokenToUnderlyingTokenMap[token]);
        _tokenToTokenType[token] = tokenType;
        emit TokenTypeChanged(token, tokenType);
    }

    // ////////////////////
    // Misc Functions
    // ////////////////////

    function getFarmTokens() public view returns (address[] memory) {
        return _supportedFarmTokens;
    }

    function isSupportedToken(address token) public view returns (bool) {
        return _tokenToIndexPlusOneMap[token] > 0;
    }

    function isFarmActive() public view returns (bool) {
        return _isFarmActive;
    }

    function guardian() public view returns (address) {
        return _guardian;
    }

    function dmgToken() public view returns (address) {
        return _dmgToken;
    }

    function dmgGrowthCoefficient() public view returns (uint) {
        return _dmgGrowthCoefficient;
    }

    function getRewardPointsByToken(
        address token
    ) public view returns (uint16) {
        uint16 rewardPoints = _tokenToRewardPointMap[token];
        return rewardPoints == 0 ? POINTS_FACTOR : rewardPoints;
    }

    function getTokenDecimalsByToken(
        address token
    ) public view returns (uint8) {
        return _tokenToDecimalsMap[token];
    }

    function getTokenIndexPlusOneByToken(
        address token
    ) public view returns (uint) {
        return _tokenToIndexPlusOneMap[token];
    }

    // ////////////////////
    // User Functions
    // ////////////////////

    function approve(
        address spender,
        bool isTrusted
    ) public {
        _userToSpenderToIsApprovedMap[msg.sender][spender] = isTrusted;
        emit Approval(msg.sender, spender, isTrusted);
    }

    function isApproved(
        address user,
        address spender
    ) public view returns (bool) {
        return _userToSpenderToIsApprovedMap[user][spender];
    }

    function beginFarming(
        address user,
        address funder,
        address token,
        uint amount
    )
    public
    farmIsActive
    requireIsFarmToken(token)
    isSpenderApproved(user)
    nonReentrant {
        require(
            funder == msg.sender || funder == user,
            "DMGYieldFarmingV2::beginFarming: INVALID_FUNDER"
        );

        if (amount > 0) {
            // In case the user is reusing a non-zero balance they had before the start of this farm.
            IERC20(token).safeTransferFrom(funder, address(this), amount);
        }

        // We reindex before adding to the user's balance, because the indexing process takes the user's CURRENT
        // balance and applies their earnings, so we can account for new deposits.
        _reindexEarningsByTimestamp(user, token);

        if (amount > 0) {
            _addressToTokenToBalanceMap[user][token] = _addressToTokenToBalanceMap[user][token].add(amount);
        }

        emit BeginFarming(user, token, amount);
    }

    function endFarmingByToken(
        address user,
        address recipient,
        address token
    )
    public
    farmIsActive
    requireIsFarmToken(token)
    isSpenderApproved(user)
    nonReentrant
    returns (uint, uint) {
        uint tokenBalance = _addressToTokenToBalanceMap[user][token];
        require(tokenBalance > 0, "DMGYieldFarmingV2::endFarmingByToken: ZERO_BALANCE");

        address dmgToken = _dmgToken;

        uint earnedDmgAmount = _getTotalRewardBalanceByUserAndToken(user, token, dmgToken, _seasonIndex);
        require(earnedDmgAmount > 0, "DMGYieldFarmingV2::endFarmingByToken: ZERO_EARNED");

        uint contractDmgRewardBalance = _getDmgRewardBalance(dmgToken);
        uint scaledTokenBalance = tokenBalance;
        if (earnedDmgAmount > contractDmgRewardBalance) {
            // Proportionally scale down the fee payment to how much DMG is actually going to be redeemed
            scaledTokenBalance = scaledTokenBalance.mul(contractDmgRewardBalance).div(earnedDmgAmount);
            earnedDmgAmount = contractDmgRewardBalance;
            require(earnedDmgAmount > 0, "DMGYieldFarmingV2::endFarmingByToken: SCALED_ZERO_EARNED");
        }
        _addressToTokenToBalanceMap[ZERO_ADDRESS][dmgToken] = _addressToTokenToBalanceMap[ZERO_ADDRESS][dmgToken].sub(earnedDmgAmount);

        {
            // To avoid the "stack too deep" error
            uint feeAmount = _payHarvestFee(user, recipient, token, scaledTokenBalance);
            // The user withdraws (balance - fee) amount.
            tokenBalance = tokenBalance.sub(feeAmount);
            IERC20(token).safeTransfer(recipient, tokenBalance);
            IERC20(dmgToken).safeTransfer(recipient, earnedDmgAmount);
        }

        _addressToTokenToBalanceMap[user][token] = 0;
        _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][user][token] = 0;
        _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][user][token] = uint64(block.timestamp);

        emit EndFarming(user, token, tokenBalance, earnedDmgAmount);

        return (tokenBalance, earnedDmgAmount);
    }

    function withdrawAllWhenOutOfSeason(
        address user,
        address recipient
    )
    public
    farmIsNotActive
    isSpenderApproved(user)
    nonReentrant
    returns (address[] memory, uint[] memory) {
        address[] memory farmTokens = _supportedFarmTokens;
        uint[] memory withdrawnAmounts = new uint[](farmTokens.length);
        for (uint i = 0; i < farmTokens.length; i++) {
            withdrawnAmounts[i] = _withdrawByTokenWhenOutOfSeason(user, recipient, farmTokens[i]);
        }
        return (farmTokens, withdrawnAmounts);
    }

    function withdrawByTokenWhenOutOfSeason(
        address user,
        address recipient,
        address token
    )
    isSpenderApproved(user)
    nonReentrant
    public returns (uint) {
        // The user can only withdraw this way if the farm is NOT active or if the token is no longer supported.
        require(
            !_isFarmActive || _tokenToIndexPlusOneMap[token] == 0,
            "DMGYieldFarmingV2::withdrawByTokenWhenOutOfSeason: FARM_ACTIVE_OR_TOKEN_SUPPORTED"
        );

        return _withdrawByTokenWhenOutOfSeason(user, recipient, token);
    }

    function getRewardBalanceByOwner(
        address owner
    ) public view returns (uint) {
        if (_isFarmActive) {
            return _getTotalRewardBalanceByUser(owner, _seasonIndex);
        } else {
            return 0;
        }
    }

    function getRewardBalanceByOwnerAndToken(
        address owner,
        address token
    ) public view returns (uint) {
        if (_isFarmActive) {
            return _getTotalRewardBalanceByUserAndToken(owner, token, _dmgToken, _seasonIndex);
        } else {
            return 0;
        }
    }

    function balanceOf(
        address owner,
        address token
    ) public view returns (uint) {
        return _addressToTokenToBalanceMap[owner][token];
    }

    function getMostRecentDepositTimestampByOwnerAndToken(
        address owner,
        address token
    ) public view returns (uint64) {
        if (_isFarmActive) {
            return _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][owner][token];
        } else {
            return 0;
        }
    }

    function getMostRecentIndexedDmgEarnedByOwnerAndToken(
        address owner,
        address token
    ) public view returns (uint) {
        if (_isFarmActive) {
            return _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][owner][token];
        } else {
            return 0;
        }
    }

    function harvestDmgByUserAndToken(
        address user,
        address recipient,
        address token
    )
    requireIsFarmToken(token)
    farmIsActive
    isSpenderApproved(user)
    nonReentrant
    public returns (uint) {
        uint tokenBalance = _addressToTokenToBalanceMap[user][token];
        return _harvestDmgByUserAndToken(user, recipient, token, tokenBalance);
    }

    function harvestDmgByUser(
        address user,
        address recipient
    )
    farmIsActive
    isSpenderApproved(user)
    nonReentrant
    public returns (uint) {
        address[] memory farmTokens = _supportedFarmTokens;
        uint totalEarnedDmgAmount = 0;
        for (uint i = 0; i < farmTokens.length; i++) {
            uint farmTokenBalance = _addressToTokenToBalanceMap[user][farmTokens[i]];
            if (farmTokenBalance > 0) {
                uint earnedDmgAmount = _harvestDmgByUserAndToken(user, recipient, farmTokens[i], farmTokenBalance);
                totalEarnedDmgAmount = totalEarnedDmgAmount.add(earnedDmgAmount);
            }
        }
        return totalEarnedDmgAmount;
    }

    function getUnderlyingTokenByFarmToken(
        address farmToken
    ) public view returns (address) {
        return _tokenToUnderlyingTokenMap[farmToken];
    }

    function underlyingTokenValuator() public view returns (address) {
        return _underlyingTokenValuator;
    }

    function weth() public view returns (address) {
        return _weth;
    }

    function uniswapV2Router() public view returns (address) {
        return _uniswapV2Router;
    }

    function getFeesByToken(address token) public view returns (uint16) {
        uint16 fee = _tokenToFeeAmountMap[token];
        return fee == 0 ? 100 : fee;
    }

    function _harvestDmgByUserAndToken(
        address user,
        address recipient,
        address token,
        uint tokenBalance
    ) internal returns (uint) {
        require(
            tokenBalance > 0,
            "DMGYieldFarmingV2::_harvestDmgByUserAndToken: ZERO_BALANCE"
        );

        address dmgToken = _dmgToken;
        uint earnedDmgAmount = _getTotalRewardBalanceByUserAndToken(user, token, dmgToken, _seasonIndex);
        require(earnedDmgAmount > 0, "DMGYieldFarmingV2::_harvestDmgByUserAndToken: ZERO_EARNED");

        uint contractDmgRewardBalance = _getDmgRewardBalance(dmgToken);
        uint scaledTokenBalance = tokenBalance;
        if (earnedDmgAmount > contractDmgRewardBalance) {
            // Proportionally scale down the fee payment to how much DMG is actually going to be redeemed
            scaledTokenBalance = scaledTokenBalance.mul(contractDmgRewardBalance).div(earnedDmgAmount);
            earnedDmgAmount = contractDmgRewardBalance;
        }
        _addressToTokenToBalanceMap[ZERO_ADDRESS][dmgToken] = _addressToTokenToBalanceMap[ZERO_ADDRESS][dmgToken].sub(earnedDmgAmount);

        {
            uint feeAmount = _payHarvestFee(user, recipient, token, scaledTokenBalance);
            _addressToTokenToBalanceMap[user][token] = _addressToTokenToBalanceMap[user][token].sub(feeAmount);
        }

        IERC20(dmgToken).safeTransfer(recipient, earnedDmgAmount);

        _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][user][token] = 0;
        _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][user][token] = uint64(block.timestamp);

        emit Harvest(user, token, earnedDmgAmount);

        return earnedDmgAmount;
    }

    // ////////////////////
    // Internal Functions
    // ////////////////////

    /**
     * @return The amount of `token` paid for the burn.
     */
    function _payHarvestFee(
        address user,
        address refundRecipient,
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
                _payFeesWithUniswapToken(user, refundRecipient, token, tokenFeeAmount);
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
        address refundRecipient,
        address token,
        uint tokenFeeAmount
    ) internal {
        address underlyingToken = _tokenToUnderlyingTokenMap[token];

        address refundToken;
        uint amountToBurn;
        uint amountToRefund;
        {
            // New context - to prevent the stack too deep error
            IERC20(token).safeTransfer(token, tokenFeeAmount);
            (uint amount0, uint amount1) = IUniswapV2Pair(token).burn(address(this));
            address token0 = IUniswapV2Pair(token).token0();
            address token1 = IUniswapV2Pair(token).token1();

            refundToken = token0 == underlyingToken ? token1 : token0;
            amountToBurn = token0 == underlyingToken ? amount0 : amount1;
            amountToRefund = token1 == underlyingToken ? amount0 : amount1;
        }

        address dmgToken = _dmgToken;
        address weth = _weth;
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

        if (refundToken == dmgToken) {
            amountToRefund = amountToRefund.add(amountsOut[amountsOut.length - 1]);
            IDMGToken(dmgToken).burn(amountToRefund);
            emit HarvestFeePaid(user, token, tokenFeeAmount, amountToRefund);
        } else {
            IDMGToken(dmgToken).burn(amountsOut[amountsOut.length - 1]);
            // Refund the rest of the mTokens
            IERC20(refundToken).safeTransfer(refundRecipient, amountToRefund);
            emit HarvestFeePaid(user, token, tokenFeeAmount, amountsOut[amountsOut.length - 1]);
        }
    }

    function _verifyDmgGrowthCoefficient(
        uint dmgGrowthCoefficient
    ) internal pure {
        require(
            dmgGrowthCoefficient > 0,
            "DMGYieldFarmingV2::_verifyDmgGrowthCoefficient: INVALID_GROWTH_COEFFICIENT"
        );
    }

    function _verifyTokenType(
        DMGYieldFarmingV2Lib.TokenType tokenType,
        address token,
        address underlyingToken
    ) internal {
        require(
            tokenType != DMGYieldFarmingV2Lib.TokenType.Unknown,
            "DMGYieldFarmingV2::_verifyTokenType: INVALID_TYPE"
        );
        if (tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapLpToken) {
            address uniswapV2Router = _uniswapV2Router;
            if (IERC20(underlyingToken).allowance(address(this), uniswapV2Router) == 0) {
                IERC20(underlyingToken).approve(uniswapV2Router, uint(- 1));
            }
        }
    }

    function _verifyTokenFees(
        uint16 fees
    ) internal pure {
        require(
            fees > 0 && fees <= FEE_AMOUNT_FACTOR,
            "DMGYieldFarmingV2::_verifyTokenFees: INVALID_FEES"
        );
    }

    function _verifyPoints(
        uint16 points
    ) internal pure {
        require(
            points > 0,
            "DMGYieldFarmingV2::_verifyPoints: INVALID_POINTS"
        );
    }

    function _getDmgRewardBalance(
        address dmgToken
    ) internal view returns (uint) {
        return _addressToTokenToBalanceMap[ZERO_ADDRESS][dmgToken];
    }

    function _getUnindexedRewardsByUserAndToken(
        address owner,
        address token,
        address dmgToken,
        uint64 previousIndexTimestamp
    ) internal view returns (uint) {
        uint balance;
        if (owner == ZERO_ADDRESS) {
            balance = IERC20(token).balanceOf(address(this));
            if (token == dmgToken) {
                balance = balance.sub(_getDmgRewardBalance(dmgToken));
            }
        } else {
            balance = _addressToTokenToBalanceMap[owner][token];
        }

        if (balance > 0 && previousIndexTimestamp != 0) {
            uint usdValue = _getUsdValueByTokenAndTokenAmount(token, balance);
            uint16 points = getRewardPointsByToken(token);
            return _calculateRewardBalance(
                usdValue,
                points,
                _dmgGrowthCoefficient,
                block.timestamp,
                previousIndexTimestamp
            );
        } else {
            return 0;
        }
    }

    function _reindexEarningsByTimestamp(
        address user,
        address token
    ) internal {
        uint seasonIndex = _seasonIndex;
        uint64 previousIndexTimestamp = _seasonIndexToUserToTokenToDepositTimestampMap[seasonIndex][user][token];
        if (previousIndexTimestamp != 0) {
            uint dmgEarnedAmount = _getUnindexedRewardsByUserAndToken(user, token, _dmgToken, previousIndexTimestamp);
            if (dmgEarnedAmount > 0) {
                _seasonIndexToUserToTokenToEarnedDmgAmountMap[seasonIndex][user][token] = _seasonIndexToUserToTokenToEarnedDmgAmountMap[seasonIndex][user][token].add(dmgEarnedAmount);
            }
        }
        _seasonIndexToUserToTokenToDepositTimestampMap[seasonIndex][user][token] = uint64(block.timestamp);
    }

    function _getTotalRewardBalanceByUserAndToken(
        address owner,
        address token,
        address dmgToken,
        uint seasonIndex
    ) internal view returns (uint) {
        uint64 previousIndexTimestamp = _seasonIndexToUserToTokenToDepositTimestampMap[seasonIndex][owner][token];
        return _getUnindexedRewardsByUserAndToken(owner, token, dmgToken, previousIndexTimestamp)
        .add(_seasonIndexToUserToTokenToEarnedDmgAmountMap[seasonIndex][owner][token]);
    }

    function _endFarmingByToken(
        address user,
        address recipient,
        address token,
        address dmgToken,
        uint tokenBalance,
        uint earnedDmgAmount
    ) internal {
        IERC20(token).safeTransfer(recipient, tokenBalance);
        IERC20(dmgToken).safeTransfer(recipient, earnedDmgAmount);

        _addressToTokenToBalanceMap[user][token] = 0;
        _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][user][token] = 0;
        _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][user][token] = uint64(block.timestamp);

        emit EndFarming(user, token, tokenBalance, earnedDmgAmount);
    }

    /**
     * @return  The dollar value of `tokenAmount`, formatted as a number with 18 decimal places
     */
    function _getUsdValueByTokenAndTokenAmount(
        address token,
        uint tokenAmount
    ) internal view returns (uint) {
        uint8 decimals = _tokenToDecimalsMap[token];
        address underlyingToken = _tokenToUnderlyingTokenMap[token];

        tokenAmount = tokenAmount
        .mul(IERC20(underlyingToken).balanceOf(token)) /* For Uniswap pools, underlying tokens are held in the pool's contract. */
        .div(IERC20(token).totalSupply(), "DMGYieldFarmingV2::_getUsdValueByTokenAndTokenAmount: INVALID_TOTAL_SUPPLY")
        .mul(2) /* The user deposits effectively 2x the value of the underlying token in total (when the pool is in equilibrium, to account for both sides of the pool. Assuming the pool is at (or close to it) equilibrium, this 2x suffices as an estimate */;

        if (decimals < 18) {
            tokenAmount = tokenAmount.mul((10 ** (18 - uint(decimals))));
        } else if (decimals > 18) {
            tokenAmount = tokenAmount.div((10 ** (uint(decimals) - 18)));
        }

        return IUnderlyingTokenValuator(_underlyingTokenValuator).getTokenValue(underlyingToken, tokenAmount);
    }

    function _calculateRewardBalance(
        uint usdValue,
        uint16 points,
        uint dmgGrowthCoefficient,
        uint currentTimestamp,
        uint previousIndexTimestamp
    ) internal pure returns (uint) {
        if (usdValue == 0) {
            return 0;
        } else {
            uint elapsedTime = currentTimestamp.sub(previousIndexTimestamp);
            // The number returned here has 18 decimal places (same as USD value), which is the same number as DMG.
            // Perfect.
            return elapsedTime
            .mul(dmgGrowthCoefficient)
            .mul(usdValue)
            .div(DMG_GROWTH_COEFFICIENT_FACTOR)
            .mul(points)
            .div(POINTS_FACTOR);
        }
    }

    function _getTotalRewardBalanceByUser(
        address owner,
        uint seasonIndex
    ) internal view returns (uint) {
        address[] memory supportedFarmTokens = _supportedFarmTokens;
        address dmgToken = _dmgToken;
        uint totalDmgEarned = 0;
        for (uint i = 0; i < supportedFarmTokens.length; i++) {
            totalDmgEarned = totalDmgEarned.add(_getTotalRewardBalanceByUserAndToken(owner, supportedFarmTokens[i], dmgToken, seasonIndex));
        }
        return totalDmgEarned;
    }

    function _withdrawByTokenWhenOutOfSeason(
        address user,
        address recipient,
        address token
    ) internal returns (uint) {
        uint amount = _addressToTokenToBalanceMap[user][token];
        if (amount > 0) {
            _addressToTokenToBalanceMap[user][token] = 0;
            IERC20(token).safeTransfer(recipient, amount);
        }

        emit WithdrawOutOfSeason(user, token, recipient, amount);

        return amount;
    }

}