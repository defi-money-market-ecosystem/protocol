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

import "../../../protocol/interfaces/IDmmController.sol";
import "../../../protocol/interfaces/IUnderlyingTokenValuator.sol";

import "../DMGYieldFarmingData.sol";
import "./IDMGYieldFarmingV1.sol";
import "./IDMGYieldFarmingV1Initializable.sol";

contract DMGYieldFarmingV1 is IDMGYieldFarmingV1, IDMGYieldFarmingV1Initializable, DMGYieldFarmingData {

    using SafeMath for uint;
    using SafeERC20 for IERC20;

    modifier isSpenderApproved(address __user) {
        require(
            msg.sender == __user || _globalProxyToIsTrustedMap[msg.sender] || _userToSpenderToIsApprovedMap[__user][msg.sender],
            "DMGYieldFarmingV1: UNAPPROVED"
        );
        _;
    }

    modifier onlyOwnerOrGuardian {
        require(
            msg.sender == _owner || msg.sender == _guardian,
            "DMGYieldFarming: UNAUTHORIZED"
        );
        _;
    }

    modifier farmIsActive {
        require(_isFarmActive, "DMGYieldFarming: FARM_NOT_ACTIVE");
        _;
    }

    modifier requireIsFarmToken(address __token) {
        require(_tokenToIndexPlusOneMap[__token] != 0, "DMGYieldFarming: TOKEN_UNSUPPORTED");
        _;
    }

    modifier farmIsNotActive {
        require(!_isFarmActive, "DMGYieldFarming: FARM_IS_ACTIVE");
        _;
    }

    function initialize(
        address __dmgToken,
        address __guardian,
        address __dmmController,
        uint __dmgGrowthCoefficient,
        address[] memory __allowableTokens,
        address[] memory __underlyingTokens,
        uint8[] memory __tokenDecimals,
        uint16[] memory __points
    )
    initializer
    public {
        DMGYieldFarmingData.initialize(__guardian);

        require(
            __allowableTokens.length == __points.length,
            "DMGYieldFarming::initialize: INVALID_LENGTH"
        );
        require(
            __points.length == __underlyingTokens.length,
            "DMGYieldFarming::initialize: INVALID_LENGTH"
        );
        require(
            __underlyingTokens.length == __tokenDecimals.length,
            "DMGYieldFarming::initialize: INVALID_LENGTH"
        );

        _dmgToken = __dmgToken;
        _guardian = __guardian;
        _dmmController = __dmmController;

        _verifyDmgGrowthCoefficient(__dmgGrowthCoefficient);
        _dmgGrowthCoefficient = __dmgGrowthCoefficient;
        _seasonIndex = 1;
        // gas savings by starting it at 1.
        _isFarmActive = false;

        for (uint i = 0; i < __allowableTokens.length; i++) {
            require(
                __allowableTokens[i] != address(0),
                "DMGYieldFarming::initialize: INVALID_UNDERLYING"
            );
            require(
                __underlyingTokens[i] != address(0),
                "DMGYieldFarming::initialize: INVALID_UNDERLYING"
            );

            _supportedFarmTokens.push(__allowableTokens[i]);
            _tokenToIndexPlusOneMap[__allowableTokens[i]] = i + 1;
            _tokenToUnderlyingTokenMap[__allowableTokens[i]] = __underlyingTokens[i];
            _tokenToDecimalsMap[__allowableTokens[i]] = __tokenDecimals[i];

            _verifyPoints(__points[i]);
            _tokenToRewardPointMap[__allowableTokens[i]] = __points[i];
        }
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
    ) external view returns (bool) {
        return _globalProxyToIsTrustedMap[__proxy];
    }

    function addAllowableToken(
        address __token,
        address __underlyingToken,
        uint8 __underlyingTokenDecimals,
        uint16 __points
    )
    public
    nonReentrant
    onlyOwner {
        uint index = _tokenToIndexPlusOneMap[__token];
        require(
            index == 0,
            "DMGYieldFarming::addAllowableToken: TOKEN_ALREADY_SUPPORTED"
        );
        _tokenToIndexPlusOneMap[__token] = _supportedFarmTokens.push(__token);
        _tokenToRewardPointMap[__token] = __points;
        _tokenToDecimalsMap[__token] = __underlyingTokenDecimals;
        emit TokenAdded(__token, __underlyingToken, __underlyingTokenDecimals, __points);
    }

    function removeAllowableToken(
        address __token
    )
    public
    nonReentrant
    farmIsNotActive
    onlyOwner {
        uint index = _tokenToIndexPlusOneMap[__token];
        require(
            index != 0,
            "DMGYieldFarming::removeAllowableToken: TOKEN_NOT_SUPPORTED"
        );
        _tokenToIndexPlusOneMap[__token] = 0;
        _tokenToRewardPointMap[__token] = 0;
        delete _supportedFarmTokens[index - 1];
        emit TokenRemoved(__token);
    }

    function setRewardPointsByToken(
        address __token,
        uint16 __points
    )
    public
    nonReentrant
    onlyOwner {
        _verifyPoints(__points);
        _tokenToRewardPointMap[__token] = __points;
        emit RewardPointsSet(__token, __points);
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

    function beginFarmingSeason(
        uint __dmgAmount
    )
    public
    onlyOwnerOrGuardian
    nonReentrant {
        require(!_isFarmActive, "DMGYieldFarming::beginFarmingSeason: FARM_ALREADY_ACTIVE");

        _seasonIndex += 1;
        _isFarmActive = true;
        IERC20(_dmgToken).safeTransferFrom(msg.sender, address(this), __dmgAmount);

        emit FarmSeasonBegun(_seasonIndex, __dmgAmount);
    }

    function endActiveFarmingSeason(
        address __dustRecipient
    )
    public
    nonReentrant {
        uint dmgBalance = IERC20(_dmgToken).balanceOf(address(this));
        // Anyone can end the farm if the DMG balance has been drawn down to 0.
        require(
            dmgBalance == 0 || msg.sender == owner() || msg.sender == _guardian,
            "DMGYieldFarming::endActiveFarmingSeason: FARM_ACTIVE_OR_INVALID_SENDER"
        );

        _isFarmActive = false;
        if (dmgBalance > 0) {
            IERC20(_dmgToken).safeTransfer(__dustRecipient, dmgBalance);
        }

        emit FarmSeasonEnd(_seasonIndex, __dustRecipient, dmgBalance);
    }

    // ////////////////////
    // Misc Functions
    // ////////////////////

    function getFarmTokens() external view returns (address[] memory) {
        return _supportedFarmTokens;
    }

    function isSupportedToken(address __token) external view returns (bool) {
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
    ) external view returns (uint8) {
        return _tokenToDecimalsMap[__token];
    }

    function getTokenIndexPlusOneByToken(
        address __token
    ) external view returns (uint) {
        return _tokenToIndexPlusOneMap[__token];
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
    ) external view returns (bool) {
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
            "DMGYieldFarmingV1::beginFarming: INVALID_FUNDER"
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
        uint balance = _addressToTokenToBalanceMap[__user][__token];
        require(balance > 0, "DMGYieldFarming::endFarmingByToken: ZERO_BALANCE");

        uint earnedDmgAmount = _getTotalRewardBalanceByUserAndToken(__user, __token, _seasonIndex);
        require(earnedDmgAmount > 0, "DMGYieldFarming::endFarmingByToken: ZERO_EARNED");

        address dmg = _dmgToken;
        uint contractDmgBalance = IERC20(dmg).balanceOf(address(this));
        _endFarmingByToken(__user, __recipient, __token, balance, earnedDmgAmount, contractDmgBalance);

        earnedDmgAmount = _transferDmgOut(__recipient, earnedDmgAmount, dmg, contractDmgBalance);

        return (balance, earnedDmgAmount);
    }

    function withdrawAllWhenOutOfSeason(
        address __user,
        address __recipient
    )
    public
    farmIsNotActive
    isSpenderApproved(__user)
    nonReentrant {
        address[] memory farmTokens = _supportedFarmTokens;
        for (uint i = 0; i < farmTokens.length; i++) {
            _withdrawByTokenWhenOutOfSeason(__user, __recipient, farmTokens[i]);
        }
    }

    function withdrawByTokenWhenOutOfSeason(
        address __user,
        address __recipient,
        address __token
    )
    isSpenderApproved(__user)
    nonReentrant
    public returns (uint) {
        require(
            !_isFarmActive || _tokenToIndexPlusOneMap[__token] == 0,
            "DMGYieldFarmingV1::withdrawByTokenWhenOutOfSeason: FARM_ACTIVE_OR_TOKEN_SUPPORTED"
        );

        return _withdrawByTokenWhenOutOfSeason(__user, __recipient, __token);
    }

    function getRewardBalanceByOwner(
        address __owner
    ) external view returns (uint) {
        if (_isFarmActive) {
            return _getTotalRewardBalanceByUser(__owner, _seasonIndex);
        } else {
            return 0;
        }
    }

    function getRewardBalanceByOwnerAndToken(
        address __owner,
        address __token
    ) external view returns (uint) {
        if (_isFarmActive) {
            return _getTotalRewardBalanceByUserAndToken(__owner, __token, _seasonIndex);
        } else {
            return 0;
        }
    }

    function balanceOf(
        address __owner,
        address __token
    ) external view returns (uint) {
        return _addressToTokenToBalanceMap[__owner][__token];
    }

    function getMostRecentDepositTimestampByOwnerAndToken(
        address __owner,
        address __token
    ) external view returns (uint64) {
        if (_isFarmActive) {
            return _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][__owner][__token];
        } else {
            return 0;
        }
    }

    function getMostRecentIndexedDmgEarnedByOwnerAndToken(
        address __owner,
        address __token
    ) external view returns (uint) {
        if (_isFarmActive) {
            return _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][__owner][__token];
        } else {
            return 0;
        }
    }

    function getMostRecentBlockTimestamp() external view returns (uint64) {
        return uint64(block.timestamp);
    }

    // ////////////////////
    // Internal Functions
    // ////////////////////

    /**
     * @return  The dollar value of `tokenAmount`, formatted as a number with 18 decimal places
     */
    function _getUsdValueByTokenAndTokenAmount(
        address __token,
        uint __tokenAmount
    ) internal view returns (uint) {
        uint8 decimals = _tokenToDecimalsMap[__token];
        address underlyingToken = _tokenToUnderlyingTokenMap[__token];

        __tokenAmount = __tokenAmount
        .mul(IERC20(underlyingToken).balanceOf(__token)) /* For Uniswap pools, underlying tokens are held in the pool's contract. */
        .div(IERC20(__token).totalSupply(), "DMGYieldFarmingV1::_getUsdValueByTokenAndTokenAmount: INVALID_TOTAL_SUPPLY")
        .mul(2) /* The __user deposits effectively 2x the amount, to account for both sides of the pool. Assuming the pool is at (or close to it) equilibrium, this 2x suffices as an estimate */;

        if (decimals < 18) {
            __tokenAmount = __tokenAmount.mul((10 ** (18 - uint(decimals))));
        } else if (decimals > 18) {
            __tokenAmount = __tokenAmount.div((10 ** (uint(decimals) - 18)));
        }

        return IDmmController(_dmmController).underlyingTokenValuator().getTokenValue(
            underlyingToken,
            __tokenAmount
        );
    }

    /**
     * @dev Transfers the __user's `__token` balance out of this contract, re-indexes the balance for the __token to be zero.
     */
    function _endFarmingByToken(
        address __user,
        address __recipient,
        address __token,
        uint __tokenBalance,
        uint __earnedDmgAmount,
        uint __contractDmgBalance
    ) internal {
        IERC20(__token).safeTransfer(__recipient, __tokenBalance);

        _addressToTokenToBalanceMap[__user][__token] = _addressToTokenToBalanceMap[__user][__token].sub(__tokenBalance);
        _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][__user][__token] = 0;
        _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][__user][__token] = uint64(block.timestamp);

        if (__earnedDmgAmount > __contractDmgBalance) {
            __earnedDmgAmount = __contractDmgBalance;
        }

        emit EndFarming(__user, __token, __tokenBalance, __earnedDmgAmount);
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

    function _reindexEarningsByTimestamp(
        address __user,
        address __token
    ) internal {
        uint64 previousIndexTimestamp = _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][__user][__token];
        if (previousIndexTimestamp != 0) {
            uint dmgEarnedAmount = _getUnindexedRewardsByUserAndToken(__user, __token, previousIndexTimestamp);
            if (dmgEarnedAmount > 0) {
                _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][__user][__token] = _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][__user][__token].add(dmgEarnedAmount);
            }
        }
        _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][__user][__token] = uint64(block.timestamp);
    }

    function _getTotalRewardBalanceByUser(
        address __owner,
        uint __seasonIndex
    ) internal view returns (uint) {
        address[] memory supportedFarmTokens = _supportedFarmTokens;
        uint totalDmgEarned = 0;
        for (uint i = 0; i < supportedFarmTokens.length; i++) {
            totalDmgEarned = totalDmgEarned.add(_getTotalRewardBalanceByUserAndToken(__owner, supportedFarmTokens[i], __seasonIndex));
        }
        return totalDmgEarned;
    }

    function _getUnindexedRewardsByUserAndToken(
        address __owner,
        address __token,
        uint64 __previousIndexTimestamp
    ) internal view returns (uint) {
        uint balance = _addressToTokenToBalanceMap[__owner][__token];
        if (balance > 0 && __previousIndexTimestamp > 0) {
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

    function _getTotalRewardBalanceByUserAndToken(
        address __owner,
        address __token,
        uint __seasonIndex
    ) internal view returns (uint) {
        // The proceeding mapping contains the aggregate of the indexed earned amounts.
        uint64 previousIndexTimestamp = _seasonIndexToUserToTokenToDepositTimestampMap[__seasonIndex][__owner][__token];
        return _getUnindexedRewardsByUserAndToken(__owner, __token, previousIndexTimestamp)
        .add(_seasonIndexToUserToTokenToEarnedDmgAmountMap[__seasonIndex][__owner][__token]);
    }

    function _verifyDmgGrowthCoefficient(
        uint __dmgGrowthCoefficient
    ) internal pure {
        require(
            __dmgGrowthCoefficient > 0,
            "DMGYieldFarming::_verifyDmgGrowthCoefficient: INVALID_GROWTH_COEFFICIENT"
        );
    }

    function _verifyPoints(
        uint16 __points
    ) internal pure {
        require(
            __points > 0,
            "DMGYieldFarming::_verifyPoints: INVALID_POINTS"
        );
    }

    function _transferDmgOut(
        address __recipient,
        uint __amount,
        address __dmg,
        uint __contractDmgBalance
    ) internal returns (uint) {
        if (__contractDmgBalance < __amount) {
            IERC20(__dmg).safeTransfer(__recipient, __contractDmgBalance);
            return __contractDmgBalance;
        } else {
            IERC20(__dmg).safeTransfer(__recipient, __amount);
            return __amount;
        }
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
            // The number returned here has 18 decimal places (same as USD value), which is the same number as DMG.
            // Perfect.
            return __currentTimestamp.sub(__previousIndexTimestamp) // elapsed time
            .mul(__dmgGrowthCoefficient)
            .mul(__points)
            .mul(__usdValue)
            .div(POINTS_FACTOR)
            .div(DMG_GROWTH_COEFFICIENT_FACTOR);
        }
    }

}
