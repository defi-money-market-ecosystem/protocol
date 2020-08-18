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
import "../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "../../protocol/interfaces/IDmmController.sol";
import "../../utils/IERC20WithDecimals.sol";

import "./IDMGYieldFarming.sol";
import "./DMGYieldFarmingData.sol";
import "./DmmControllerHelper.sol";

contract DMGYieldFarming is IDMGYieldFarming, DMGYieldFarmingData, Ownable, ReentrancyGuard {

    using SafeMath for uint;
    using SafeERC20 for IERC20;
    using DmmControllerHelper for IFarmDmmController;

    address private _dmgToken;
    address private _dmmController;
    uint private _farmIndex;

    /// @notice How much DMG is earned every second of farming. This number is represented as a fraction with 18
    //          decimal places, whereby 0.01 == 1000000000000000.
    uint private _dmgGrowthCoefficient;
    bool private _isFarmActive;
    mapping(uint => uint16) private _dmmTokenIdToRewardPointMap;
    mapping(uint => mapping(address => uint)) private _farmIndexToAddressToEarnedDmgAmountMap;
    mapping(uint => mapping(address => mapping(uint => uint64))) private _farmIndexToAddressToTokenIdToDepositTimestampMap;
    mapping(address => mapping(uint => uint)) private _addressToTokenIdToBalanceMap;

    modifier farmIsActive {
        require(_isFarmActive, "DMGYieldFarming: FARM_NOT_ACTIVE");
        _;
    }

    modifier farmIsNotActive {
        require(!_isFarmActive, "DMGYieldFarming: FARM_IS_ACTIVE");
        _;
    }

    constructor(address dmgToken, address dmmController) public {
        _dmgToken = dmgToken;
        _dmmController = dmmController;
        _farmIndex = 0;
        _isFarmActive = false;
    }

    // ////////////////////
    // Admin Functions
    // ////////////////////

    function beginFarmCampaign(address funder, uint dmgAmount) external nonReentrant onlyOwner {
        require(!_isFarmActive, "DMGYieldFarming::beginFarmCampaign: FARM_ALREADY_ACTIVE");

        _farmIndex += 1;
        _isFarmActive = true;
        IERC20(_dmgToken).safeTransferFrom(funder, address(this), dmgAmount);

        emit FarmCampaignBegun(_farmIndex, dmgAmount);
    }

    function endActiveFarmCampaign(address dustRecipient) external nonReentrant {
        require(_isFarmActive, "DMGYieldFarming::endActiveFarmCampaign: FARM_NOT_ACTIVE");

        uint dmgBalance = IERC20(_dmgToken).balanceOf(address(this));
        // Anyone can end the farm if the DMG balance has been drawn down to 0.
        require(dmgBalance == 0 || msg.sender == owner(), "DMGYieldFarming: FARM_ACTIVE or INVALID_SENDER");

        _isFarmActive = false;
        if (dmgBalance > 0) {
            IERC20(_dmgToken).safeTransfer(dustRecipient, dmgBalance);
        }

        emit FarmCampaignEnd(_farmIndex, dustRecipient);
    }

    function setRewardPointsByDmmTokenId(uint dmmTokenId, uint16 points) external nonReentrant onlyOwner {
        _dmmTokenIdToRewardPointMap[dmmTokenId] = points;
        emit RewardPointsSet(dmmTokenId, points);
    }

    function setDmgGrowthCoefficient(uint dmgGrowthCoefficient) external nonReentrant onlyOwner {
        _dmgGrowthCoefficient = dmgGrowthCoefficient;
        emit DmgGrowthCoefficientSet(dmgGrowthCoefficient);
    }

    // ////////////////////
    // Misc Functions
    // ////////////////////

    function isFarmActive() external view returns (bool) {
        return _isFarmActive;
    }

    function dmgToken() external view returns (address) {
        return _dmgToken;
    }

    function dmmController() external view returns (address) {
        return _dmmController;
    }

    function dmgGrowthEfficient() external view returns (uint) {
        return _dmgGrowthCoefficient;
    }

    function getRewardPointsByDmmTokenId(uint dmmTokenId) public view returns (uint16) {
        uint16 rewardPoints = _dmmTokenIdToRewardPointMap[dmmTokenId];
        return rewardPoints == 0 ? ONE_REWARD_POINTS : rewardPoints;
    }

    // ////////////////////
    // User Functions
    // ////////////////////

    function beginFarm(uint dmmTokenId, uint amount) external farmIsActive nonReentrant {
        address token = IFarmDmmController(_dmmController).getDmmTokenAddressByDmmTokenId(dmmTokenId);
        if (amount > 0) {
            // In case the user is reusing a non-zero balance they had before the start of this farm.
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }

        // We reindex before adding to the user's balance, because the indexing process takes the user's CURRENT
        // balance and applies their earnings, so we can account for new deposits.
        _reindex(dmmTokenId, /* shouldAddToBalance */ true);

        _addressToTokenIdToBalanceMap[msg.sender][dmmTokenId] = _addressToTokenIdToBalanceMap[msg.sender][dmmTokenId].add(amount);
    }

    function endFarm() external farmIsActive nonReentrant returns (uint) {
        uint totalEarnedDmgAmount = 0;
        uint[] memory dmmTokenIds = IDmmController(_dmmController).getDmmTokenIds();
        for (uint i = 0; i < dmmTokenIds.length; i++) {
            uint balance = _addressToTokenIdToBalanceMap[msg.sender][dmmTokenIds[i]];
            if (balance > 0) {
                uint earnedDmgAmount = _rewardBalanceOf(msg.sender, dmmTokenIds[i]);
                _endFarmByDmmTokenId(dmmTokenIds[i], balance);
                totalEarnedDmgAmount = totalEarnedDmgAmount.add(earnedDmgAmount);
            }
        }
        return totalEarnedDmgAmount;
    }

    function endFarmByDmmTokenId(uint dmmTokenId) external farmIsActive nonReentrant returns (uint, uint) {
        uint balance = _addressToTokenIdToBalanceMap[msg.sender][dmmTokenId];
        require(balance > 0, "DMGYieldFarming::endFarmByDmmTokenId: ZERO_BALANCE");

        uint earnedDmgAmount = _rewardBalanceOf(msg.sender, dmmTokenId);
        IERC20(_dmgToken).safeTransfer(msg.sender, earnedDmgAmount);

        _endFarmByDmmTokenId(dmmTokenId, balance);

        return (balance, earnedDmgAmount);
    }

    function withdrawAllWhenOutOfSeason() external farmIsNotActive nonReentrant {
        uint[] memory dmmTokenIds = IDmmController(_dmmController).getDmmTokenIds();
        for (uint i = 0; i < dmmTokenIds.length; i++) {
            _withdrawByDmmTokenIdWhenOutOfSeason(dmmTokenIds[i]);
        }
    }

    function withdrawByDmmTokenIdWhenOutOfSeason(uint dmmTokenId) external farmIsNotActive nonReentrant {
        require(
            _addressToTokenIdToBalanceMap[msg.sender][dmmTokenId] > 0,
            "DMGYieldFarming::withdrawByDmmTokenIdWhenOutOfSeason: ZERO_BALANCE"
        );
        _withdrawByDmmTokenIdWhenOutOfSeason(dmmTokenId);
    }

    function rewardBalanceOf(address owner) external view returns (uint) {
        if (_isFarmActive) {
            uint rewardBalance = 0;
            uint[] memory dmmTokenIds = IDmmController(_dmmController).getDmmTokenIds();
            uint dmgGrowthCoefficient = _dmgGrowthCoefficient;
            uint16 pointsFactor = ONE_REWARD_POINTS;
            for (uint i = 0; i < dmmTokenIds.length; i++) {
                uint tokenEarnedBalance = _rewardBalanceOf(owner, dmmTokenIds[i]);
                rewardBalance = rewardBalance.add(tokenEarnedBalance);
            }
            return rewardBalance;
        } else {
            return 0;
        }
    }

    function balanceOf(address owner, uint dmmTokenId) external view returns (uint) {
        return _addressToTokenIdToBalanceMap[owner][dmmTokenId];
    }

    // ////////////////////
    // Internal Functions
    // ////////////////////

    function _endFarmByDmmTokenId(uint dmmTokenId, uint balance) internal {
        address token = IFarmDmmController(_dmmController).getDmmTokenAddressByDmmTokenId(dmmTokenId);
        IERC20(token).safeTransfer(msg.sender, balance);
        _reindex(dmmTokenId, /* shouldAddToBalance */ false);
        _addressToTokenIdToBalanceMap[msg.sender][dmmTokenId] = 0;
    }

    function _withdrawByDmmTokenIdWhenOutOfSeason(uint dmmTokenId) internal {
        address token = IFarmDmmController(_dmmController).getDmmTokenAddressByDmmTokenId(dmmTokenId);
        uint amount = _addressToTokenIdToBalanceMap[msg.sender][dmmTokenId];
        _addressToTokenIdToBalanceMap[msg.sender][dmmTokenId] = 0;
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function _reindex(uint dmmTokenId, bool shouldAddToBalance) internal {
        uint64 previousIndexTimestamp = _farmIndexToAddressToTokenIdToDepositTimestampMap[_farmIndex][msg.sender][dmmTokenId];
        if (previousIndexTimestamp != 0) {
            uint dmgEarnedAmount = _rewardBalanceOf(msg.sender, dmmTokenId);
            if (dmgEarnedAmount > 0) {
                uint previousDmgEarnedAmount = _farmIndexToAddressToEarnedDmgAmountMap[_farmIndex][msg.sender];
                if (shouldAddToBalance) {
                    _farmIndexToAddressToEarnedDmgAmountMap[_farmIndex][msg.sender] = previousDmgEarnedAmount.add(dmgEarnedAmount);
                } else {
                    _farmIndexToAddressToEarnedDmgAmountMap[_farmIndex][msg.sender] = previousDmgEarnedAmount.sub(dmgEarnedAmount);
                }
            }
        }
        _farmIndexToAddressToTokenIdToDepositTimestampMap[_farmIndex][msg.sender][dmmTokenId] = uint64(block.timestamp);
    }

    function _rewardBalanceOf(address owner, uint dmmTokenId) internal view returns (uint) {
        uint balance = _addressToTokenIdToBalanceMap[owner][dmmTokenId];
        if (balance > 0) {
            uint64 previousIndexTimestamp = _farmIndexToAddressToTokenIdToDepositTimestampMap[_farmIndex][owner][dmmTokenId];
            address token = IFarmDmmController(_dmmController).getDmmTokenAddressByDmmTokenId(dmmTokenId);
            uint balanceFactor = 10 ** uint(IERC20WithDecimals(token).decimals());
            uint16 points = getRewardPointsByDmmTokenId(dmmTokenId);
            return _calculateRewardBalance(
                balance,
                balanceFactor,
                points,
                ONE_REWARD_POINTS,
                _dmgGrowthCoefficient,
                uint64(block.timestamp),
                previousIndexTimestamp
            );
        } else {
            return 0;
        }
    }

    function _calculateRewardBalance(
        uint balance,
        uint balanceFactor,
        uint16 points,
        uint16 pointsFactor,
        uint dmgGrowthCoefficient,
        uint64 currentTimestamp,
        uint64 previousIndexTimestamp
    ) internal pure returns (uint) {
        if (balance == 0) {
            return 0;
        } else {
            uint elapsedTime = currentTimestamp - previousIndexTimestamp;
            uint rawDmgEarnedAmount = elapsedTime.mul(dmgGrowthCoefficient).div(1e18);
            return rawDmgEarnedAmount.mul(points).div(pointsFactor).mul(balance).div(balanceFactor);
        }
    }

}
