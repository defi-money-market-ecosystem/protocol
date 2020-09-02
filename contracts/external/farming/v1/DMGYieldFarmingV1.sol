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
        DMGYieldFarmingData.initialize();

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
        _farmIndex = 1;
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
    }

    function removeAllowableToken(
        address token
    )
    public
    nonReentrant
    onlyOwner {
        uint index = _tokenToIndexPlusOneMap[token];
        require(
            index != 0,
            "DMGYieldFarming::addAllowableToken: TOKEN_NOT_SUPPORTED"
        );
        _tokenToIndexPlusOneMap[token] = 0;
        _tokenToRewardPointMap[token] = 0;
        delete _supportedFarmTokens[index - 1];
    }

    function beginFarmingCampaign(
        address funder,
        uint dmgAmount
    ) public nonReentrant onlyOwner {
        require(!_isFarmActive, "DMGYieldFarming::beginFarmingCampaign: FARM_ALREADY_ACTIVE");

        _farmIndex += 1;
        _isFarmActive = true;
        IERC20(_dmgToken).safeTransferFrom(funder, address(this), dmgAmount);

        emit FarmCampaignBegun(_farmIndex, dmgAmount);
    }

    function endActiveFarmingCampaign(
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

        emit FarmCampaignEnd(_farmIndex, dustRecipient);
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

    // ////////////////////
    // Misc Functions
    // ////////////////////

    function getFarmTokens() public view returns (address[] memory) {
        return _supportedFarmTokens;
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

    function dmgGrowthEfficient() public view returns (uint) {
        return _dmgGrowthCoefficient;
    }

    function getRewardPointsByToken(
        address token
    ) public view returns (uint16) {
        uint16 rewardPoints = _tokenToRewardPointMap[token];
        return rewardPoints == 0 ? POINTS_FACTOR : rewardPoints;
    }

    // ////////////////////
    // User Functions
    // ////////////////////

    function beginFarming(
        address token,
        uint amount
    )
    public
    farmIsActive
    nonReentrant {
        if (amount > 0) {
            // In case the user is reusing a non-zero balance they had before the start of this farm.
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        // We reindex before adding to the user's balance, because the indexing process takes the user's CURRENT
        // balance and applies their earnings, so we can account for new deposits.
        _reindexEarningsByTimestamp(token);

        if (amount > 0) {
            _addressToTokenToBalanceMap[msg.sender][token] = _addressToTokenToBalanceMap[msg.sender][token].add(amount);
        }

        emit BeginFarming(msg.sender, token, amount);
    }

    function endFarming() public farmIsActive nonReentrant returns (uint) {
        uint farmIndex = _farmIndex;
        uint totalDmgEarned = _getTotalRewardBalanceByUser(msg.sender, farmIndex);
        if (totalDmgEarned > 0) {
            address[] memory farmTokens = _supportedFarmTokens;
            for (uint i = 0; i < farmTokens.length; i++) {
                uint balance = _addressToTokenToBalanceMap[msg.sender][farmTokens[i]];
                if (balance > 0) {
                    _endFarmingByToken(
                        farmTokens[i],
                        balance,
                        _getTotalRewardBalanceByUserAndToken(msg.sender, farmTokens[i], farmIndex)
                    );
                }
            }
            IERC20(_dmgToken).safeTransfer(msg.sender, totalDmgEarned);
        }
        return totalDmgEarned;
    }

    function endFarmingByToken(
        address token
    ) public farmIsActive nonReentrant returns (uint, uint) {
        uint balance = _addressToTokenToBalanceMap[msg.sender][token];
        require(balance > 0, "DMGYieldFarming::endFarmingByToken: ZERO_BALANCE");

        uint earnedDmgAmount = _getTotalRewardBalanceByUserAndToken(msg.sender, token, _farmIndex);
        require(earnedDmgAmount > 0, "DMGYieldFarming::endFarmingByToken: ZERO_EARNED");

        _endFarmingByToken(token, balance, earnedDmgAmount);

        IERC20(_dmgToken).safeTransfer(msg.sender, earnedDmgAmount);

        return (balance, earnedDmgAmount);
    }

    function withdrawAllWhenOutOfSeason() public farmIsNotActive nonReentrant {
        address[] memory farmTokens = _supportedFarmTokens;
        for (uint i = 0; i < farmTokens.length; i++) {
            _withdrawByTokenWhenOutOfSeason(farmTokens[i]);
        }
    }

    function withdrawByTokenWhenOutOfSeason(address token) public farmIsNotActive nonReentrant {
        require(
            _addressToTokenToBalanceMap[msg.sender][token] > 0,
            "DMGYieldFarming::withdrawByTokenWhenOutOfSeason: ZERO_BALANCE"
        );
        _withdrawByTokenWhenOutOfSeason(token);
    }

    function rewardBalanceOf(
        address owner
    ) public view returns (uint) {
        if (_isFarmActive) {
            return _getTotalRewardBalanceByUser(owner, _farmIndex);
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
        .div(IERC20(token).totalSupply());

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
        address token,
        uint tokenBalance,
        uint earnedDmgAmount
    ) internal {
        IERC20(token).safeTransfer(msg.sender, tokenBalance);

        _addressToTokenToBalanceMap[msg.sender][token] = _addressToTokenToBalanceMap[msg.sender][token].sub(tokenBalance);
        _farmIndexToUserToTokenToEarnedDmgAmountMap[_farmIndex][msg.sender][token] = 0;
        _farmIndexToUserToTokenToDepositTimestampMap[_farmIndex][msg.sender][token] = uint64(block.timestamp);

        emit EndFarming(msg.sender, token, tokenBalance, earnedDmgAmount);
    }

    function _withdrawByTokenWhenOutOfSeason(
        address token
    ) internal {
        uint amount = _addressToTokenToBalanceMap[msg.sender][token];
        _addressToTokenToBalanceMap[msg.sender][token] = 0;
        IERC20(token).safeTransfer(msg.sender, amount);

        emit WithdrawOutOfSeason(msg.sender, token, amount);
    }

    function _reindexEarningsByTimestamp(
        address token
    ) internal {
        uint64 previousIndexTimestamp = _farmIndexToUserToTokenToDepositTimestampMap[_farmIndex][msg.sender][token];
        if (previousIndexTimestamp != 0) {
            uint dmgEarnedAmount = _getUnindexedRewardsByUserAndToken(msg.sender, token, previousIndexTimestamp);
            if (dmgEarnedAmount > 0) {
                _farmIndexToUserToTokenToEarnedDmgAmountMap[_farmIndex][msg.sender][token] = _farmIndexToUserToTokenToEarnedDmgAmountMap[_farmIndex][msg.sender][token].add(dmgEarnedAmount);
            }
        }
        _farmIndexToUserToTokenToDepositTimestampMap[_farmIndex][msg.sender][token] = uint64(block.timestamp);
    }

    function _getTotalRewardBalanceByUser(
        address owner,
        uint farmIndex
    ) internal view returns (uint) {
        address[] memory supportedFarmTokens = _supportedFarmTokens;
        uint totalDmgEarned = 0;
        for (uint i = 0; i < supportedFarmTokens.length; i++) {
            totalDmgEarned = totalDmgEarned.add(_getTotalRewardBalanceByUserAndToken(owner, supportedFarmTokens[i], farmIndex));
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
            uint farmIndex = _farmIndex;
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
        uint farmIndex
    ) internal view returns (uint) {
        // The proceeding mapping contains the aggregate of the indexed earned amounts.
        uint64 previousIndexTimestamp = _farmIndexToUserToTokenToDepositTimestampMap[farmIndex][owner][token];
        return _getUnindexedRewardsByUserAndToken(owner, token, previousIndexTimestamp)
        .add(_farmIndexToUserToTokenToEarnedDmgAmountMap[farmIndex][owner][token]);
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

            return elapsedTime
            .mul(dmgGrowthCoefficient)
            .div(DMG_GROWTH_COEFFICIENT_FACTOR)
            .mul(points)
            .div(POINTS_FACTOR)
            .mul(usdValue)
            .div(USD_VALUE_FACTOR);
        }
    }

}
