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
import "../../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../../../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../../../protocol/interfaces/IDmmController.sol";
import "../../../protocol/interfaces/IUnderlyingTokenValuator.sol";

import "../DMGYieldFarmingData.sol";
import "./IDMGYieldFarmingV1.sol";
import "./IDMGYieldFarmingV1Initializable.sol";

contract DMGYieldFarmingV1 is IDMGYieldFarmingV1, IDMGYieldFarmingV1Initializable, DMGYieldFarmingData {

    using SafeMath for uint;
    using SafeERC20 for IERC20;

    modifier isSpenderApproved(address user) {
        require(
            msg.sender == user || _userToSpenderToIsApprovedMap[user][msg.sender],
            "DMGYieldFarmingV1: UNAPPROVED"
        );

        _;
    }

    modifier farmIsActive {
        require(_isFarmActive, "DMGYieldFarming: FARM_NOT_ACTIVE");
        _;
    }

    modifier requireIsFarmToken(address token) {
        require(_tokenToIndexPlusOneMap[token] != 0, "DMGYieldFarming: TOKEN_UNSUPPORTED");
        _;
    }

    modifier farmIsNotActive {
        require(!_isFarmActive, "DMGYieldFarming: FARM_IS_ACTIVE");
        _;
    }

    function initialize(
        address dmgToken,
        address guardian,
        address dmmController,
        uint dmgGrowthCoefficient,
        address[] memory allowableTokens,
        address[] memory underlyingTokens,
        uint8[] memory tokenDecimals,
        uint16[] memory points
    )
    initializer
    public {
        DMGYieldFarmingData.initialize(guardian);

        require(
            allowableTokens.length == points.length,
            "DMGYieldFarming::initialize: INVALID_LENGTH"
        );
        require(
            points.length == underlyingTokens.length,
            "DMGYieldFarming::initialize: INVALID_LENGTH"
        );
        require(
            underlyingTokens.length == tokenDecimals.length,
            "DMGYieldFarming::initialize: INVALID_LENGTH"
        );

        _dmgToken = dmgToken;
        _guardian = guardian;
        _dmmController = dmmController;

        _verifyDmgGrowthCoefficient(dmgGrowthCoefficient);
        _dmgGrowthCoefficient = dmgGrowthCoefficient;
        _seasonIndex = 1;
        // gas savings by starting it at 1.
        _isFarmActive = false;

        for (uint i = 0; i < allowableTokens.length; i++) {
            require(
                allowableTokens[i] != address(0),
                "DMGYieldFarming::initialize: INVALID_UNDERLYING"
            );
            require(
                underlyingTokens[i] != address(0),
                "DMGYieldFarming::initialize: INVALID_UNDERLYING"
            );

            _supportedFarmTokens.push(allowableTokens[i]);
            _tokenToIndexPlusOneMap[allowableTokens[i]] = i + 1;
            _tokenToUnderlyingTokenMap[allowableTokens[i]] = underlyingTokens[i];
            _tokenToDecimalsMap[allowableTokens[i]] = tokenDecimals[i];

            _verifyPoints(points[i]);
            _tokenToRewardPointMap[allowableTokens[i]] = points[i];
        }
    }

    // ////////////////////
    // Admin Functions
    // ////////////////////

    function addAllowableToken(
        address token,
        address underlyingToken,
        uint8 underlyingTokenDecimals,
        uint16 points
    )
    public
    nonReentrant
    onlyOwner {
        uint index = _tokenToIndexPlusOneMap[token];
        require(
            index == 0,
            "DMGYieldFarming::addAllowableToken: TOKEN_ALREADY_SUPPORTED"
        );
        _tokenToIndexPlusOneMap[token] = _supportedFarmTokens.push(token);
        _tokenToRewardPointMap[token] = points;
        _tokenToDecimalsMap[token] = underlyingTokenDecimals;
        emit TokenAdded(token, underlyingToken, underlyingTokenDecimals, points);
    }

    function removeAllowableToken(
        address token
    )
    public
    nonReentrant
    farmIsNotActive
    onlyOwner {
        uint index = _tokenToIndexPlusOneMap[token];
        require(
            index != 0,
            "DMGYieldFarming::removeAllowableToken: TOKEN_NOT_SUPPORTED"
        );
        _tokenToIndexPlusOneMap[token] = 0;
        _tokenToRewardPointMap[token] = 0;
        delete _supportedFarmTokens[index - 1];
        emit TokenRemoved(token);
    }

    function setRewardPointsByToken(
        address token,
        uint16 points
    )
    public
    nonReentrant
    onlyOwner {
        _verifyPoints(points);
        _tokenToRewardPointMap[token] = points;
        emit RewardPointsSet(token, points);
    }

    function setDmgGrowthCoefficient(
        uint dmgGrowthCoefficient
    )
    public
    nonReentrant
    onlyOwner {
        _verifyDmgGrowthCoefficient(dmgGrowthCoefficient);

        _dmgGrowthCoefficient = dmgGrowthCoefficient;
        emit DmgGrowthCoefficientSet(dmgGrowthCoefficient);
    }

    function beginFarmingSeason(
        uint dmgAmount
    )
    public
    nonReentrant
    onlyOwner {
        require(!_isFarmActive, "DMGYieldFarming::beginFarmingSeason: FARM_ALREADY_ACTIVE");

        _seasonIndex += 1;
        _isFarmActive = true;
        IERC20(_dmgToken).safeTransferFrom(msg.sender, address(this), dmgAmount);

        emit FarmSeasonBegun(_seasonIndex, dmgAmount);
    }

    function endActiveFarmingSeason(
        address dustRecipient
    )
    public
    nonReentrant {
        uint dmgBalance = IERC20(_dmgToken).balanceOf(address(this));
        // Anyone can end the farm if the DMG balance has been drawn down to 0.
        require(
            dmgBalance == 0 || msg.sender == owner() || msg.sender == _guardian,
            "DMGYieldFarming: FARM_ACTIVE or INVALID_SENDER"
        );

        _isFarmActive = false;
        if (dmgBalance > 0) {
            IERC20(_dmgToken).safeTransfer(dustRecipient, dmgBalance);
        }

        emit FarmSeasonEnd(_seasonIndex, dustRecipient, dmgBalance);
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
            "DMGYieldFarmingV1::beginFarming: INVALID_FUNDER"
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
        uint balance = _addressToTokenToBalanceMap[user][token];
        require(balance > 0, "DMGYieldFarming::endFarmingByToken: ZERO_BALANCE");

        uint earnedDmgAmount = _getTotalRewardBalanceByUserAndToken(user, token, _seasonIndex);
        require(earnedDmgAmount > 0, "DMGYieldFarming::endFarmingByToken: ZERO_EARNED");

        address dmgToken = _dmgToken;
        uint contractDmgBalance = IERC20(dmgToken).balanceOf(address(this));
        _endFarmingByToken(user, recipient, token, balance, earnedDmgAmount, contractDmgBalance);

        earnedDmgAmount = _transferDmgOut(recipient, earnedDmgAmount, dmgToken, contractDmgBalance);

        return (balance, earnedDmgAmount);
    }

    function withdrawAllWhenOutOfSeason(
        address user,
        address recipient
    )
    public
    farmIsNotActive
    isSpenderApproved(user)
    nonReentrant {
        address[] memory farmTokens = _supportedFarmTokens;
        for (uint i = 0; i < farmTokens.length; i++) {
            _withdrawByTokenWhenOutOfSeason(user, recipient, farmTokens[i]);
        }
    }

    function withdrawByTokenWhenOutOfSeason(
        address user,
        address recipient,
        address token
    )
    isSpenderApproved(user)
    nonReentrant
    public returns (uint) {
        require(
            !_isFarmActive || _tokenToIndexPlusOneMap[token] == 0,
            "DMGYieldFarmingV1::withdrawByTokenWhenOutOfSeason: FARM_ACTIVE_OR_TOKEN_SUPPORTED"
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
            return _getTotalRewardBalanceByUserAndToken(owner, token, _seasonIndex);
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

    function getMostRecentBlockTimestamp() public view returns (uint64) {
        return uint64(block.timestamp);
    }

    // ////////////////////
    // Internal Functions
    // ////////////////////

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
        .mul(IERC20(underlyingToken).balanceOf(token)) // For Uniswap pools, underlying tokens are held in the pool's contract.
        .div(IERC20(token).totalSupply(), "DMGYieldFarmingV1::_getUsdValueByTokenAndTokenAmount: INVALID_TOTAL_SUPPLY");

        if (decimals < 18) {
            tokenAmount = tokenAmount.mul((10 ** (18 - uint(decimals))));
        } else if (decimals > 18) {
            tokenAmount = tokenAmount.div((10 ** (uint(decimals) - 18)));
        }

        return IDmmController(_dmmController).underlyingTokenValuator().getTokenValue(
            underlyingToken,
            tokenAmount
        );
    }

    /**
     * @dev Transfers the user's `token` balance out of this contract, re-indexes the balance for the token to be zero.
     */
    function _endFarmingByToken(
        address user,
        address recipient,
        address token,
        uint tokenBalance,
        uint earnedDmgAmount,
        uint contractDmgBalance
    ) internal {
        IERC20(token).safeTransfer(recipient, tokenBalance);

        _addressToTokenToBalanceMap[user][token] = _addressToTokenToBalanceMap[user][token].sub(tokenBalance);
        _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][user][token] = 0;
        _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][user][token] = uint64(block.timestamp);

        if (earnedDmgAmount > contractDmgBalance) {
            earnedDmgAmount = contractDmgBalance;
        }

        emit EndFarming(user, token, tokenBalance, earnedDmgAmount);
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

    function _reindexEarningsByTimestamp(
        address user,
        address token
    ) internal {
        uint64 previousIndexTimestamp = _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][user][token];
        if (previousIndexTimestamp != 0) {
            uint dmgEarnedAmount = _getUnindexedRewardsByUserAndToken(user, token, previousIndexTimestamp);
            if (dmgEarnedAmount > 0) {
                _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][user][token] = _seasonIndexToUserToTokenToEarnedDmgAmountMap[_seasonIndex][user][token].add(dmgEarnedAmount);
            }
        }
        _seasonIndexToUserToTokenToDepositTimestampMap[_seasonIndex][user][token] = uint64(block.timestamp);
    }

    function _getTotalRewardBalanceByUser(
        address owner,
        uint seasonIndex
    ) internal view returns (uint) {
        address[] memory supportedFarmTokens = _supportedFarmTokens;
        uint totalDmgEarned = 0;
        for (uint i = 0; i < supportedFarmTokens.length; i++) {
            totalDmgEarned = totalDmgEarned.add(_getTotalRewardBalanceByUserAndToken(owner, supportedFarmTokens[i], seasonIndex));
        }
        return totalDmgEarned;
    }

    function _getUnindexedRewardsByUserAndToken(
        address owner,
        address token,
        uint64 previousIndexTimestamp
    ) internal view returns (uint) {
        uint balance = _addressToTokenToBalanceMap[owner][token];
        if (balance > 0 && previousIndexTimestamp > 0) {
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

    function _getTotalRewardBalanceByUserAndToken(
        address owner,
        address token,
        uint seasonIndex
    ) internal view returns (uint) {
        // The proceeding mapping contains the aggregate of the indexed earned amounts.
        uint64 previousIndexTimestamp = _seasonIndexToUserToTokenToDepositTimestampMap[seasonIndex][owner][token];
        return _getUnindexedRewardsByUserAndToken(owner, token, previousIndexTimestamp)
        .add(_seasonIndexToUserToTokenToEarnedDmgAmountMap[seasonIndex][owner][token]);
    }

    function _verifyDmgGrowthCoefficient(
        uint dmgGrowthCoefficient
    ) internal pure {
        require(
            dmgGrowthCoefficient > 0,
            "DMGYieldFarming::_verifyDmgGrowthCoefficient: INVALID_GROWTH_COEFFICIENT"
        );
    }

    function _verifyPoints(
        uint16 points
    ) internal pure {
        require(
            points > 0,
            "DMGYieldFarming::_verifyPoints: INVALID_POINTS"
        );
    }

    function _transferDmgOut(
        address recipient,
        uint amount,
        address dmgToken,
        uint contractDmgBalance
    ) internal returns (uint) {
        if (contractDmgBalance < amount) {
            IERC20(dmgToken).safeTransfer(recipient, contractDmgBalance);
            return contractDmgBalance;
        } else {
            IERC20(dmgToken).safeTransfer(recipient, amount);
            return amount;
        }
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
            .div(DMG_GROWTH_COEFFICIENT_FACTOR)
            .mul(points)
            .div(POINTS_FACTOR)
            .mul(usdValue);
        }
    }

}
