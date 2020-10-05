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
import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../../uniswap/interfaces/IUniswapV2Pair.sol";
import "../../uniswap/interfaces/IUniswapV2Router02.sol";
import "../../uniswap/libs/UniswapV2Library.sol";

import "../../../governance/dmg/IDMGToken.sol";
import "../../../protocol/interfaces/IDmmController.sol";
import "../../../protocol/interfaces/IUnderlyingTokenValuator.sol";
import "../../../utils/IERC20WithDecimals.sol";

import "../v1/IDMGYieldFarmingV1.sol";
import "../v1/IDMGYieldFarmingV1Initializable.sol";
import "../DMGYieldFarmingData.sol";
import "./IDMGYieldFarmingV2.sol";
import "../../uniswap/UniswapV2Router02.sol";

contract DMGYieldFarmingV2 is IDMGYieldFarmingV2, DMGYieldFarmingData {

    using SafeMath for uint;
    using SafeERC20 for IERC20;
    using UniswapV2Library for *;

    address constant public ZERO_ADDRESS = address(0);

    modifier isSpenderApproved(address __user) {
        require(
            msg.sender == __user || _globalProxyToIsTrustedMap[msg.sender] || _userToSpenderToIsApprovedMap[__user][msg.sender],
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

    modifier requireIsFarmToken(address __token) {
        require(_tokenToIndexPlusOneMap[__token] != 0, "DMGYieldFarmingV2: TOKEN_UNSUPPORTED");
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
        address __proxy,
        bool __isTrusted
    )
    public
    nonReentrant
    onlyOwnerOrGuardian {
        _globalProxyToIsTrustedMap[__proxy] = __isTrusted;
        emit GlobalProxySet(__proxy, __isTrusted);
    }

    function isGloballyTrustedProxy(
        address __proxy
    ) public view returns (bool) {
        return _globalProxyToIsTrustedMap[__proxy];
    }

    function addAllowableToken(
        address __token,
        address __underlyingToken,
        uint8 __underlyingTokenDecimals,
        uint16 __points,
        uint16 __fees,
        DMGYieldFarmingV2Lib.TokenType __tokenType
    )
    public
    onlyOwnerOrGuardian
    nonReentrant {
        uint index = _tokenToIndexPlusOneMap[__token];
        require(
            index == 0,
            "DMGYieldFarmingV2::addAllowableToken: TOKEN_ALREADY_SUPPORTED"
        );
        _verifyTokenFee(__fees);
        _verifyTokenType(__tokenType, __underlyingToken);
        _verifyPoints(__points);

        _tokenToIndexPlusOneMap[__token] = _supportedFarmTokens.push(__token);
        _tokenToRewardPointMap[__token] = __points;
        _tokenToDecimalsMap[__token] = __underlyingTokenDecimals;
        _tokenToTokenType[__token] = __tokenType;
        _tokenToUnderlyingTokenMap[__token] = __underlyingToken;
        emit TokenAdded(__token, __underlyingToken, __underlyingTokenDecimals, __points, __fees);
    }

    function removeAllowableToken(
        address __token
    )
    public
    onlyOwnerOrGuardian
    nonReentrant
    farmIsNotActive {
        uint index = _tokenToIndexPlusOneMap[__token];
        require(
            index != 0,
            "DMGYieldFarmingV2::removeAllowableToken: TOKEN_NOT_SUPPORTED"
        );
        _tokenToIndexPlusOneMap[__token] = 0;
        _tokenToRewardPointMap[__token] = 0;
        delete _supportedFarmTokens[index - 1];
        emit TokenRemoved(__token);
    }

    function beginFarmingSeason(
        uint __dmgAmount
    )
    public
    onlyOwnerOrGuardian
    nonReentrant {
        require(!_isFarmActive, "DMGYieldFarmingV2::beginFarmingSeason: FARM_ALREADY_ACTIVE");

        _seasonIndex += 1;
        _isFarmActive = true;
        address dmgToken = _dmgToken;
        IERC20(dmgToken).safeTransferFrom(msg.sender, address(this), __dmgAmount);
        _addressToTokenToBalanceMap[ZERO_ADDRESS][dmgToken] = _addressToTokenToBalanceMap[ZERO_ADDRESS][dmgToken].add(__dmgAmount);
        _seasonIndexToStartTimestamp[_seasonIndex] = uint64(block.timestamp);

        emit FarmSeasonBegun(_seasonIndex, __dmgAmount);
    }

    function endActiveFarmingSeason(
        address __dustRecipient
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
            IERC20(dmgToken).safeTransfer(__dustRecipient, dmgBalance);
        }

        emit FarmSeasonEnd(_seasonIndex, __dustRecipient, dmgBalance);
    }

    function setDmgGrowthCoefficient(
        uint __dmgGrowthCoefficient
    )
    public
    nonReentrant
    onlyOwnerOrGuardian {
        _verifyDmgGrowthCoefficient(__dmgGrowthCoefficient);

        _dmgGrowthCoefficient = __dmgGrowthCoefficient;
        emit DmgGrowthCoefficientSet(__dmgGrowthCoefficient);
    }

    function setRewardPointsByTokens(
        address[] calldata __tokens,
        uint16[] calldata __points
    )
    external
    nonReentrant
    onlyOwnerOrGuardian {
        require(
            __tokens.length == __points.length,
            "DMGYieldFarmingV2::setRewardPointsByTokens INVALID_PARAMS"
        );

        for (uint i = 0; i < __tokens.length; i++) {
            _setRewardPointsByToken(__tokens[i], __points[i]);
        }
    }

    function setUnderlyingTokenValuator(
        address __underlyingTokenValuator
    )
    onlyOwnerOrGuardian
    nonReentrant
    public {
        require(
            __underlyingTokenValuator != address(0),
            "DMGYieldFarmingV2::setUnderlyingTokenValuator: INVALID_VALUATOR"
        );
        address oldUnderlyingTokenValuator = _underlyingTokenValuator;
        _underlyingTokenValuator = __underlyingTokenValuator;
        emit UnderlyingTokenValuatorChanged(__underlyingTokenValuator, oldUnderlyingTokenValuator);
    }

    function setWethToken(
        address __weth
    )
    onlyOwnerOrGuardian
    nonReentrant
    public {
        require(
            _weth == address(0),
            "DMGYieldFarmingV2::setWethToken: WETH_ALREADY_SET"
        );
        _weth = __weth;
    }

    function setUniswapV2Router(
        address __uniswapV2Router
    )
    onlyOwnerOrGuardian
    nonReentrant
    public {
        require(
            __uniswapV2Router != address(0),
            "DMGYieldFarmingV2::setUnderlyingTokenValuator: INVALID_VALUATOR"
        );
        address oldUniswapV2Router = _uniswapV2Router;
        _uniswapV2Router = __uniswapV2Router;
        emit UniswapV2RouterChanged(__uniswapV2Router, oldUniswapV2Router);
    }

    function setFeesByTokens(
        address[] calldata __tokens,
        uint16[] calldata __fees
    )
    onlyOwnerOrGuardian
    nonReentrant
    external {
        require(
            __tokens.length == __fees.length,
            "DMGYieldFarmingV2::setFeesByTokens: INVALID_PARAMS"
        );

        for (uint i = 0; i < __tokens.length; i++) {
            _setFeeByToken(__tokens[i], __fees[i]);
        }
    }

    function setTokenTypeByToken(
        address __token,
        DMGYieldFarmingV2Lib.TokenType __tokenType
    )
    onlyOwnerOrGuardian
    nonReentrant
    requireIsFarmToken(__token)
    public {
        _verifyTokenType(__tokenType, _tokenToUnderlyingTokenMap[__token]);
        _tokenToTokenType[__token] = __tokenType;
        emit TokenTypeChanged(__token, __tokenType);
    }

    function initializeDmgBalance() nonReentrant external {
        require(
            !_isDmgBalanceInitialized,
            "DMGYieldFarmingV2::initializeDmgBalance: ALREADY_INITIALIZED"
        );
        _isDmgBalanceInitialized = true;
        _addressToTokenToBalanceMap[ZERO_ADDRESS][_dmgToken] = IERC20(_dmgToken).balanceOf(address(this));
    }

    // ////////////////////
    // Misc Functions
    // ////////////////////

    function getFarmTokens() public view returns (address[] memory) {
        return _supportedFarmTokens;
    }

    function isSupportedToken(address __token) public view returns (bool) {
        return _tokenToIndexPlusOneMap[__token] > 0;
    }

    function isFarmActive() external view returns (bool) {
        return _isFarmActive;
    }

    function guardian() external view returns (address) {
        return _guardian;
    }

    function dmgToken() external view returns (address) {
        return _dmgToken;
    }

    function dmgGrowthCoefficient() external view returns (uint) {
        return _dmgGrowthCoefficient;
    }

    function getRewardPointsByToken(
        address __token
    ) public view returns (uint16) {
        uint16 rewardPoints = _tokenToRewardPointMap[__token];
        return rewardPoints == 0 ? POINTS_FACTOR : rewardPoints;
    }

    function getTokenDecimalsByToken(
        address __token
    ) public view returns (uint8) {
        return _tokenToDecimalsMap[__token];
    }

    function getTokenIndexPlusOneByToken(
        address __token
    ) public view returns (uint) {
        return _tokenToIndexPlusOneMap[__token];
    }

    function getTokenTypeByToken(
        address __token
    ) public view returns (DMGYieldFarmingV2Lib.TokenType) {
        return _tokenToTokenType[__token];
    }

    // ////////////////////
    // User Functions
    // ////////////////////

    function approve(
        address __spender,
        bool __isTrusted
    ) public {
        _userToSpenderToIsApprovedMap[msg.sender][__spender] = __isTrusted;
        emit Approval(msg.sender, __spender, __isTrusted);
    }

    function isApproved(
        address __user,
        address __spender
    ) public view returns (bool) {
        return _userToSpenderToIsApprovedMap[__user][__spender];
    }

    function beginFarming(
        address __user,
        address __funder,
        address __token,
        uint __amount
    )
    public
    farmIsActive
    requireIsFarmToken(__token)
    isSpenderApproved(__user)
    nonReentrant {
        require(
            __funder == msg.sender || __funder == __user,
            "DMGYieldFarmingV2::beginFarming: INVALID_FUNDER"
        );

        if (__amount > 0) {
            // In case the __user is reusing a non-zero balance they had before the start of this farm.
            IERC20(__token).safeTransferFrom(__funder, address(this), __amount);
        }

        // We reindex before adding to the __user's balance, because the indexing process takes the __user's CURRENT
        // balance and applies their earnings, so we can account for new deposits.
        _reindexEarningsByTimestamp(__user, __token);

        if (__amount > 0) {
            _addressToTokenToBalanceMap[__user][__token] = _addressToTokenToBalanceMap[__user][__token].add(__amount);
        }

        emit BeginFarming(__user, __token, __amount);
    }

    function endFarmingByToken(
        address __user,
        address __recipient,
        address __token
    )
    public
    farmIsActive
    requireIsFarmToken(__token)
    isSpenderApproved(__user)
    nonReentrant
    returns (uint, uint) {
        uint tokenBalance = _addressToTokenToBalanceMap[__user][__token];
        require(tokenBalance > 0, "DMGYieldFarmingV2::endFarmingByToken: ZERO_BALANCE");

        address dmg = _dmgToken;

        uint earnedDmgAmount = _getTotalRewardBalanceByUserAndToken(__user, __token, dmg, _seasonIndex);
        require(earnedDmgAmount > 0, "DMGYieldFarmingV2::endFarmingByToken: ZERO_EARNED");

        uint contractDmgRewardBalance = _getDmgRewardBalance(dmg);
        uint scaledTokenBalance = tokenBalance;
        if (earnedDmgAmount > contractDmgRewardBalance) {
            // Proportionally scale down the fee payment to how much DMG is actually going to be redeemed
            scaledTokenBalance = scaledTokenBalance.mul(contractDmgRewardBalance).div(earnedDmgAmount);
            earnedDmgAmount = contractDmgRewardBalance;
            require(earnedDmgAmount > 0, "DMGYieldFarmingV2::endFarmingByToken: SCALED_ZERO_EARNED");
        }
        _addressToTokenToBalanceMap[ZERO_ADDRESS][dmg] = _addressToTokenToBalanceMap[ZERO_ADDRESS][dmg].sub(earnedDmgAmount);

        {
            // To avoid the "stack too deep" error
            uint feeAmount = _payHarvestFee(__user, __token, scaledTokenBalance);
            // The __user withdraws (balance - fee) amount.
            tokenBalance = tokenBalance.sub(feeAmount);
            IERC20(__token).safeTransfer(__recipient, tokenBalance);
            IERC20(dmg).safeTransfer(__recipient, earnedDmgAmount);
        }

        _addressToTokenToBalanceMap[__user][__token] = 0;
        _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][__user][__token] = 0;
        _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][__user][__token] = uint64(block.timestamp);

        emit EndFarming(__user, __token, tokenBalance, earnedDmgAmount);

        return (tokenBalance, earnedDmgAmount);
    }

    function withdrawAllWhenOutOfSeason(
        address __user,
        address __recipient
    )
    public
    farmIsNotActive
    isSpenderApproved(__user)
    nonReentrant
    returns (address[] memory, uint[] memory) {
        address[] memory farmTokens = _supportedFarmTokens;
        uint[] memory withdrawnAmounts = new uint[](farmTokens.length);
        for (uint i = 0; i < farmTokens.length; i++) {
            withdrawnAmounts[i] = _withdrawByTokenWhenOutOfSeason(__user, __recipient, farmTokens[i]);
        }
        return (farmTokens, withdrawnAmounts);
    }

    function withdrawByTokenWhenOutOfSeason(
        address __user,
        address __recipient,
        address __token
    )
    isSpenderApproved(__user)
    nonReentrant
    public returns (uint) {
        // The __user can only withdraw this way if the farm is NOT active or if the __token is no longer supported.
        require(
            !_isFarmActive || _tokenToIndexPlusOneMap[__token] == 0,
            "DMGYieldFarmingV2::withdrawByTokenWhenOutOfSeason: FARM_ACTIVE_OR_TOKEN_SUPPORTED"
        );

        return _withdrawByTokenWhenOutOfSeason(__user, __recipient, __token);
    }

    function getRewardBalanceByOwner(
        address __owner
    ) public view returns (uint) {
        if (_isFarmActive) {
            return _getTotalRewardBalanceByUser(__owner, _seasonIndex);
        } else {
            return 0;
        }
    }

    function getRewardBalanceByOwnerAndToken(
        address __owner,
        address __token
    ) public view returns (uint) {
        if (_isFarmActive) {
            return _getTotalRewardBalanceByUserAndToken(__owner, __token, _dmgToken, _seasonIndex);
        } else {
            return 0;
        }
    }

    function balanceOf(
        address __owner,
        address __token
    ) public view returns (uint) {
        return _addressToTokenToBalanceMap[__owner][__token];
    }

    function getMostRecentDepositTimestampByOwnerAndToken(
        address __owner,
        address __token
    ) public view returns (uint64) {
        if (_isFarmActive) {
            return _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][__owner][__token];
        } else {
            return 0;
        }
    }

    function getMostRecentIndexedDmgEarnedByOwnerAndToken(
        address __owner,
        address __token
    ) public view returns (uint) {
        if (_isFarmActive) {
            return _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][__owner][__token];
        } else {
            return 0;
        }
    }

    function harvestDmgByUserAndToken(
        address __user,
        address __recipient,
        address __token
    )
    requireIsFarmToken(__token)
    farmIsActive
    isSpenderApproved(__user)
    nonReentrant
    public returns (uint) {
        uint tokenBalance = _addressToTokenToBalanceMap[__user][__token];
        return _harvestDmgByUserAndToken(__user, __recipient, __token, tokenBalance);
    }

    function harvestDmgByUser(
        address __user,
        address __recipient
    )
    farmIsActive
    isSpenderApproved(__user)
    nonReentrant
    public returns (uint) {
        address[] memory farmTokens = _supportedFarmTokens;
        uint totalEarnedDmgAmount = 0;
        for (uint i = 0; i < farmTokens.length; i++) {
            uint farmTokenBalance = _addressToTokenToBalanceMap[__user][farmTokens[i]];
            if (farmTokenBalance > 0) {
                uint earnedDmgAmount = _harvestDmgByUserAndToken(__user, __recipient, farmTokens[i], farmTokenBalance);
                totalEarnedDmgAmount = totalEarnedDmgAmount.add(earnedDmgAmount);
            }
        }
        return totalEarnedDmgAmount;
    }

    function getUnderlyingTokenByFarmToken(
        address __farmToken
    ) public view returns (address) {
        return _tokenToUnderlyingTokenMap[__farmToken];
    }

    function underlyingTokenValuator() external view returns (address) {
        return _underlyingTokenValuator;
    }

    function weth() external view returns (address) {
        return _weth;
    }

    function uniswapV2Router() external view returns (address) {
        return _uniswapV2Router;
    }

    function getFeesByToken(
        address __token
    ) public view returns (uint16) {
        uint16 fee = _tokenToFeeAmountMap[__token];
        return fee == 0 ? 100 : fee;
    }

    // ////////////////////
    // Internal Functions
    // ////////////////////

    function _setFeeByToken(
        address __token,
        uint16 __fee
    ) internal {
        _verifyTokenFee(__fee);
        _tokenToFeeAmountMap[__token] = __fee;
        emit FeesChanged(__token, __fee);
    }

    function _setRewardPointsByToken(
        address __token,
        uint16 __points
    ) internal {
        _verifyPoints(__points);
        _tokenToRewardPointMap[__token] = __points;
        emit RewardPointsSet(__token, __points);
    }

    function _verifyDmgGrowthCoefficient(
        uint __dmgGrowthCoefficient
    ) internal pure {
        require(
            __dmgGrowthCoefficient > 0,
            "DMGYieldFarmingV2::_verifyDmgGrowthCoefficient: INVALID_GROWTH_COEFFICIENT"
        );
    }

    function _verifyTokenType(
        DMGYieldFarmingV2Lib.TokenType __tokenType,
        address __underlyingToken
    ) internal {
        require(
            __tokenType != DMGYieldFarmingV2Lib.TokenType.Unknown,
            "DMGYieldFarmingV2::_verifyTokenType: INVALID_TYPE"
        );

        if (__tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapLpToken) {
            address __uniswapV2Router = _uniswapV2Router;
            if (IERC20(__underlyingToken).allowance(address(this), __uniswapV2Router) == 0) {
                IERC20(__underlyingToken).safeApprove(__uniswapV2Router, uint(- 1));
            }
        }
    }

    function _verifyTokenFee(
        uint16 __fee
    ) internal pure {
        require(
            __fee >= 0 && __fee < FEE_AMOUNT_FACTOR,
            "DMGYieldFarmingV2::_verifyTokenFee: INVALID_FEES"
        );
    }

    function _verifyPoints(
        uint16 __points
    ) internal pure {
        require(
            __points > 0,
            "DMGYieldFarmingV2::_verifyPoints: INVALID_POINTS"
        );
    }

    function _getDmgRewardBalance(
        address __dmgToken
    ) internal view returns (uint) {
        return _addressToTokenToBalanceMap[ZERO_ADDRESS][__dmgToken];
    }

    function _harvestDmgByUserAndToken(
        address __user,
        address __recipient,
        address __token,
        uint __tokenBalance
    ) internal returns (uint) {
        require(
            __tokenBalance > 0,
            "DMGYieldFarmingV2::_harvestDmgByUserAndToken: ZERO_BALANCE"
        );

        address dmg = _dmgToken;
        uint earnedDmgAmount = _getTotalRewardBalanceByUserAndToken(__user, __token, dmg, _seasonIndex);
        require(earnedDmgAmount > 0, "DMGYieldFarmingV2::_harvestDmgByUserAndToken: ZERO_EARNED");

        uint contractDmgRewardBalance = _getDmgRewardBalance(dmg);
        uint scaledTokenBalance = __tokenBalance;
        if (earnedDmgAmount > contractDmgRewardBalance) {
            // Proportionally scale down the fee payment to how much DMG is actually going to be redeemed
            scaledTokenBalance = scaledTokenBalance.mul(contractDmgRewardBalance).div(earnedDmgAmount);
            earnedDmgAmount = contractDmgRewardBalance;
        }
        _addressToTokenToBalanceMap[ZERO_ADDRESS][dmg] = _addressToTokenToBalanceMap[ZERO_ADDRESS][dmg].sub(earnedDmgAmount);

        {
            uint feeAmount = _payHarvestFee(__user, __token, scaledTokenBalance);
            _addressToTokenToBalanceMap[__user][__token] = _addressToTokenToBalanceMap[__user][__token].sub(feeAmount);
        }

        IERC20(dmg).safeTransfer(__recipient, earnedDmgAmount);

        _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][__user][__token] = 0;
        _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][__user][__token] = uint64(block.timestamp);

        emit Harvest(__user, __token, earnedDmgAmount);

        return earnedDmgAmount;
    }

    function _getUnindexedRewardsByUserAndToken(
        address __owner,
        address __token,
        address __dmgToken,
        uint64 __previousIndexTimestamp
    ) internal view returns (uint) {
        uint balance;
        if (__owner == ZERO_ADDRESS) {
            balance = IERC20(__token).balanceOf(address(this));
            if (__token == __dmgToken) {
                balance = balance.sub(_getDmgRewardBalance(__dmgToken));
            }
        } else {
            balance = _addressToTokenToBalanceMap[__owner][__token];
        }

        if (balance > 0 && __previousIndexTimestamp != 0) {
            uint usdValue = _getUsdValueByTokenAndTokenAmount(__token, balance);
            uint16 points = getRewardPointsByToken(__token);
            return _calculateRewardBalance(
                usdValue,
                points,
                _dmgGrowthCoefficient,
                block.timestamp,
                __previousIndexTimestamp
            );
        } else {
            return 0;
        }
    }

    function _reindexEarningsByTimestamp(
        address __user,
        address __token
    ) internal {
        uint seasonIndex = _seasonIndex;
        uint64 previousIndexTimestamp = _seasonIndexToUserToTokenToDepositTimestampMap[seasonIndex][__user][__token];
        if (previousIndexTimestamp != 0) {
            uint dmgEarnedAmount = _getUnindexedRewardsByUserAndToken(__user, __token, _dmgToken, previousIndexTimestamp);
            if (dmgEarnedAmount > 0) {
                _seasonIndexToUserToTokenToEarnedDmgAmountMap[seasonIndex][__user][__token] = _seasonIndexToUserToTokenToEarnedDmgAmountMap[seasonIndex][__user][__token].add(dmgEarnedAmount);
            }
        }
        _seasonIndexToUserToTokenToDepositTimestampMap[seasonIndex][__user][__token] = uint64(block.timestamp);
    }

    function _getTotalRewardBalanceByUserAndToken(
        address __owner,
        address __token,
        address __dmgToken,
        uint __seasonIndex
    ) internal view returns (uint) {
        uint64 previousIndexTimestamp = _seasonIndexToUserToTokenToDepositTimestampMap[__seasonIndex][__owner][__token];
        return _getUnindexedRewardsByUserAndToken(__owner, __token, __dmgToken, previousIndexTimestamp)
        .add(_seasonIndexToUserToTokenToEarnedDmgAmountMap[__seasonIndex][__owner][__token]);
    }

    /**
     * @return  The dollar value of `tokenAmount`, formatted as a number with 18 decimal places
     */
    function _getUsdValueByTokenAndTokenAmount(
        address __farmToken,
        uint __tokenAmount
    ) internal view returns (uint) {
        address underlyingToken = _tokenToUnderlyingTokenMap[__farmToken];
        address mToken;
        address __underlyingTokenValuator = _underlyingTokenValuator;
        DMGYieldFarmingV2Lib.TokenType tokenType = _tokenToTokenType[__farmToken];

        if (tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapLpToken) {
            {
                // New context to prevent "stack too deep" errors
                address token0 = IUniswapV2Pair(__farmToken).token0();
                mToken = underlyingToken == token0 ? IUniswapV2Pair(__farmToken).token1() : token0;
            }
            uint totalSupply = IERC20(__farmToken).totalSupply();
            require(
                totalSupply > 0,
                "DMGYieldFarmingV2::_getUsdValueByTokenAndTokenAmount: INVALID_TOTAL_SUPPLY"
            );

            address dmmController = _dmmController;

            uint underlyingTokenUsdValue = _getUnderlyingTokenUsdValueFromUniswapPool(
                __tokenAmount,
                totalSupply,
                __farmToken,
                underlyingToken,
                __underlyingTokenValuator
            );

            uint mTokenUsdValue = _getMTokenUsdValueFromUniswapPool(
                __tokenAmount,
                totalSupply,
                __farmToken,
                mToken,
                dmmController,
                __underlyingTokenValuator
            );

            return underlyingTokenUsdValue.add(mTokenUsdValue);
        } else {
            revert("DMGYieldFarmingV2::_getUsdValueByTokenAndTokenAmount: INVALID_TOKEN_TYPE");
        }
    }

    function _getUnderlyingTokenUsdValueFromUniswapPool(
        uint __tokenAmount,
        uint __totalSupply,
        address __farmToken,
        address __underlyingToken,
        address __underlyingTokenValuator
    ) internal view returns (uint) {
        uint underlyingTokenValue = __tokenAmount
        .mul(IERC20(__underlyingToken).balanceOf(__farmToken)) // For Uniswap, underlying tokens are held in the contract.
        .div(__totalSupply);

        return _getUsdValueForUnderlyingTokenAmount(
            __underlyingToken,
            __underlyingTokenValuator,
            _tokenToDecimalsMap[__farmToken],
            underlyingTokenValue
        );
    }

    function _getMTokenUsdValueFromUniswapPool(
        uint __tokenAmount,
        uint __totalSupply,
        address __farmToken,
        address __mToken,
        address __dmmController,
        address __underlyingTokenValuator
    ) internal view returns (uint) {
        uint mTokenAmount = __tokenAmount
        .mul(IERC20(__mToken).balanceOf(__farmToken)) // For Uniswap, underlying tokens are held in the contract.
        .div(__totalSupply);

        return _getUsdValueForUnderlyingTokenAmount(
            IDmmController(__dmmController).getUnderlyingTokenForDmm(__mToken),
            __underlyingTokenValuator,
            IERC20WithDecimals(__mToken).decimals(),
            mTokenAmount.mul(IDmmController(__dmmController).getExchangeRate(__mToken)).div(1e18)
        );
    }

    function _getUsdValueForUnderlyingTokenAmount(
        address __underlyingToken,
        address __underlyingTokenValuator,
        uint8 __decimals,
        uint __amount
    ) internal view returns (uint) {
        if (__decimals < 18) {
            __amount = __amount.mul((10 ** (18 - uint(__decimals))));
        } else if (__decimals > 18) {
            __amount = __amount.div((10 ** (uint(__decimals) - 18)));
        }
        return IUnderlyingTokenValuator(__underlyingTokenValuator).getTokenValue(__underlyingToken, __amount);
    }

    function _calculateRewardBalance(
        uint __usdValue,
        uint16 __points,
        uint __dmgGrowthCoefficient,
        uint __currentTimestamp,
        uint __previousIndexTimestamp
    ) internal pure returns (uint) {
        if (__usdValue == 0) {
            return 0;
        } else {
            uint elapsedTime = __currentTimestamp.sub(__previousIndexTimestamp);
            // The number returned here has 18 decimal places (same as USD value), which is the same number as DMG.
            // Perfect.
            return elapsedTime
            .mul(__dmgGrowthCoefficient)
            .mul(__usdValue)
            .div(DMG_GROWTH_COEFFICIENT_FACTOR)
            .mul(__points)
            .div(POINTS_FACTOR);
        }
    }

    function _getTotalRewardBalanceByUser(
        address __owner,
        uint __seasonIndex
    ) internal view returns (uint) {
        address[] memory supportedFarmTokens = _supportedFarmTokens;
        address dmg = _dmgToken;
        uint totalDmgEarned = 0;
        for (uint i = 0; i < supportedFarmTokens.length; i++) {
            totalDmgEarned = totalDmgEarned.add(_getTotalRewardBalanceByUserAndToken(__owner, supportedFarmTokens[i], dmg, __seasonIndex));
        }
        return totalDmgEarned;
    }

    function _withdrawByTokenWhenOutOfSeason(
        address __user,
        address __recipient,
        address __token
    ) internal returns (uint) {
        uint amount = _addressToTokenToBalanceMap[__user][__token];
        if (amount > 0) {
            _addressToTokenToBalanceMap[__user][__token] = 0;
            IERC20(__token).safeTransfer(__recipient, amount);
        }

        emit WithdrawOutOfSeason(__user, __token, __recipient, amount);

        return amount;
    }

    /**
     * @return The amount of `__token` paid for the burn.
     */
    function _payHarvestFee(
        address __user,
        address __token,
        uint __tokenAmount
    ) internal returns (uint) {
        uint fees = getFeesByToken(__token);
        if (fees > 0) {
            uint tokenFeeAmount = __tokenAmount.mul(fees).div(uint(FEE_AMOUNT_FACTOR));
            DMGYieldFarmingV2Lib.TokenType tokenType = _tokenToTokenType[__token];
            require(
                tokenType != DMGYieldFarmingV2Lib.TokenType.Unknown,
                "DMGYieldFarmingV2::_payHarvestFee: UNKNOWN_TOKEN_TYPE"
            );

            if (tokenType == DMGYieldFarmingV2Lib.TokenType.UniswapLpToken) {
                _payFeesWithUniswapToken(__user, __token, tokenFeeAmount);
            } else {
                revert("DMGYieldFarmingV2::_payHarvestFee UNCAUGHT_TOKEN_TYPE");
            }

            return tokenFeeAmount;
        } else {
            return 0;
        }
    }

    function _payFeesWithUniswapToken(
        address __user,
        address __token,
        uint __tokenFeeAmount
    ) internal {
        address underlyingToken = _tokenToUnderlyingTokenMap[__token];

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

        address dmg = _dmgToken;
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

        uint dmgToBurn = _swapTokensForDmgViaUniswap(amountToBurn, underlyingToken, _weth, dmg);

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
        uint __amountToBurn,
        address __underlyingToken,
        address __weth,
        address __dmg
    ) internal returns (uint) {
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
        uint[] memory amountsOut = IUniswapV2Router02(_uniswapV2Router).swapExactTokensForTokens(
            __amountToBurn,
        /* amountOutMin */ 1,
            paths,
            address(this),
            block.timestamp
        );

        return amountsOut[amountsOut.length - 1];
    }

}