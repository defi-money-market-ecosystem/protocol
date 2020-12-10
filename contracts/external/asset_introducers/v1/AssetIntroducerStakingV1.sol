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
pragma experimental ABIEncoderV2;

import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../../protocol/interfaces/IDmmController.sol";
import "../../../utils/IERC20WithDecimals.sol";

import "../interfaces/IERC721TokenReceiver.sol";
import "../interfaces/IERC721.sol";

import "./IAssetIntroducerStakingV1Initializable.sol";
import "./IAssetIntroducerV1.sol";
import "./IAssetIntroducerStakingV1.sol";
import "../AssetIntroducerStakingData.sol";

contract AssetIntroducerStakingV1 is IAssetIntroducerStakingV1Initializable, IAssetIntroducerStakingV1, IERC721TokenReceiver, AssetIntroducerStakingData {

    using SafeERC20 for IERC20;
    using SafeMath for uint;

    uint constant internal ONE_ETH = 1 ether;

    function initialize(
        address __assetIntroducerProxy,
        address __dmgIncentivesPool
    ) public initializer {
        _assetIntroducerProxy = __assetIntroducerProxy;
        _dmgIncentivesPool = __dmgIncentivesPool;
        _guardCounter = 1;
    }

    function assetIntroducerProxy() external view returns (address) {
        return _assetIntroducerProxy;
    }

    function dmg() public view returns (address) {
        return IAssetIntroducerV1(_assetIntroducerProxy).dmg();
    }

    function dmgIncentivesPool() external view returns (address) {
        return _dmgIncentivesPool;
    }

    function buyAssetIntroducerSlot(
        uint __tokenId,
        uint __dmmTokenId,
        StakingDuration __duration
    )
    external
    nonReentrant
    returns (bool) {
        IAssetIntroducerV1 __assetIntroducerProxy = IAssetIntroducerV1(_assetIntroducerProxy);
        (uint fullPriceDmg, uint additionalDiscount) = getAssetIntroducerPriceDmgByTokenIdAndStakingDuration(__tokenId, __duration);
        uint userPriceDmg = fullPriceDmg / 2;

        address __dmg = dmg();
        address __dmgIncentivesPool = _dmgIncentivesPool;

        require(
            IERC20(__dmg).balanceOf(__dmgIncentivesPool) >= fullPriceDmg.sub(userPriceDmg),
            "AssetIntroducerBuyerRouter::buyAssetIntroducerSlot: INSUFFICIENT_INCENTIVES"
        );
        IERC20(__dmg).safeTransferFrom(__dmgIncentivesPool, address(this), fullPriceDmg.sub(userPriceDmg));
        IERC20(__dmg).safeTransferFrom(msg.sender, address(this), userPriceDmg);

        _performStakingForToken(__tokenId, __dmmTokenId, __duration, __assetIntroducerProxy);

        IERC20(__dmg).safeApprove(address(__assetIntroducerProxy), fullPriceDmg);
        __assetIntroducerProxy.buyAssetIntroducerSlotViaStaking(__tokenId, additionalDiscount);

        // Forward the NFT to the purchaser
        IERC721(address(__assetIntroducerProxy)).safeTransferFrom(address(this), msg.sender, __tokenId);

        emit IncentiveDmgUsed(__tokenId, msg.sender, fullPriceDmg.sub(userPriceDmg));

        return true;
    }

    function withdrawStake() external nonReentrant {
        UserStake[] memory userStakes = _userToStakesMap[msg.sender];
        for (uint i = 0; i < userStakes.length; i++) {
            if (!userStakes[i].isWithdrawn && block.timestamp > userStakes[i].unlockTimestamp) {
                _userToStakesMap[msg.sender][i].isWithdrawn = true;
                IERC20(userStakes[i].mToken).safeTransfer(msg.sender, userStakes[i].amount);
                emit UserEndStaking(msg.sender, userStakes[i].tokenId, userStakes[i].mToken, userStakes[i].amount);
            }
        }
    }

    function getUserStakesByAddress(
        address user
    ) external view returns (AssetIntroducerStakingData.UserStake[] memory) {
        return _userToStakesMap[user];
    }

    function getActiveUserStakesByAddress(
        address user
    ) external view returns (AssetIntroducerStakingData.UserStake[] memory) {
        AssetIntroducerStakingData.UserStake[] memory allStakes = _userToStakesMap[user];

        uint count = 0;
        for (uint i = 0; i < allStakes.length; i++) {
            if (!allStakes[i].isWithdrawn) {
                count += 1;
            }
        }

        AssetIntroducerStakingData.UserStake[] memory activeStakes = new AssetIntroducerStakingData.UserStake[](count);
        count = 0;
        for (uint i = 0; i < allStakes.length; i++) {
            if (!allStakes[i].isWithdrawn) {
                activeStakes[count++] = allStakes[i];
            }
        }
        return activeStakes;
    }

    function balanceOf(
        address user,
        address mToken
    ) external view returns (uint) {
        uint balance = 0;
        AssetIntroducerStakingData.UserStake[] memory allStakes = _userToStakesMap[user];
        for (uint i = 0; i < allStakes.length; i++) {
            if (!allStakes[i].isWithdrawn && allStakes[i].mToken == mToken) {
                balance += allStakes[i].amount;
            }
        }
        return balance;
    }

    function getStakeAmountByTokenIdAndDmmTokenId(
        uint __tokenId,
        uint __dmmTokenId
    ) public view returns (uint) {
        uint priceUsd = IAssetIntroducerV1(_assetIntroducerProxy).getAssetIntroducerPriceUsdByTokenId(__tokenId);
        return _getStakeAmountByDmmTokenId(__dmmTokenId, priceUsd);
    }

    function getStakeAmountByCountryCodeAndIntroducerTypeAndDmmTokenId(
        string calldata __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType,
        uint __dmmTokenId
    ) external view returns (uint) {
        uint priceUsd = IAssetIntroducerV1(_assetIntroducerProxy).getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(__countryCode, __introducerType);
        return _getStakeAmountByDmmTokenId(__dmmTokenId, priceUsd);
    }

    function mapDurationEnumToSeconds(
        StakingDuration __duration
    ) public pure returns (uint64) {
        if (__duration == StakingDuration.TWELVE_MONTHS) {
            return 86400 * 30 * 12;
        } else if (__duration == StakingDuration.EIGHTEEN_MONTHS) {
            return 86400 * 30 * 18;
        } else {
            revert("AssetIntroducerStakingV1::mapDurationEnumToSeconds: INVALID_DURATION");
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function isReady() public view returns (bool) {
        return IERC20(dmg()).allowance(_dmgIncentivesPool, address(this)) > 0 &&
        IAssetIntroducerV1(_assetIntroducerProxy).stakingPurchaser() == address(this);
    }

    function getAssetIntroducerPriceDmgByTokenIdAndStakingDuration(
        uint __tokenId,
        StakingDuration __duration
    ) public view returns (uint, uint) {
        IAssetIntroducerV1 __assetIntroducerProxy = IAssetIntroducerV1(_assetIntroducerProxy);
        uint nonStakingDiscount = __assetIntroducerProxy.getAssetIntroducerDiscount();
        uint totalDiscount = getTotalDiscountByStakingDuration(__duration);
        uint additionalDiscount = totalDiscount.sub(nonStakingDiscount);

        uint fullPriceDmg = __assetIntroducerProxy.getAssetIntroducerPriceDmgByTokenId(__tokenId);
        uint originalPriceDmg = fullPriceDmg.mul(ONE_ETH).div(ONE_ETH.sub(nonStakingDiscount));

        return (originalPriceDmg.mul(ONE_ETH.sub(totalDiscount)).div(ONE_ETH), additionalDiscount);
    }

    function getTotalDiscountByStakingDuration(
        StakingDuration duration
    ) public view returns (uint) {
        uint baseDiscount;
        uint originalDiscount;
        // The discount expired
        if (duration == StakingDuration.TWELVE_MONTHS) {
            // Discount is 95% at t=0 and decays to 25% at t=18_months; delta of 70%
            originalDiscount = 0.7 ether;
            baseDiscount = 0.25 ether;
        } else if (duration == StakingDuration.EIGHTEEN_MONTHS) {
            // Discount is 99% at t=0 and decays to 50% at t=18_months; delta of 49%
            originalDiscount = 0.49 ether;
            baseDiscount = 0.50 ether;
        } else {
            revert("AssetIntroducerStakingV1::getTotalDiscountByStakingDuration: INVALID_DURATION");
        }

        uint elapsedTime = block.timestamp.sub(IAssetIntroducerV1(_assetIntroducerProxy).initTimestamp());
        // 18 months or 540 days
        uint discountDurationInSeconds = 86400 * 30 * 18;
        if (elapsedTime > discountDurationInSeconds) {
            return baseDiscount;
        } else {
            return (originalDiscount.mul(discountDurationInSeconds.sub(elapsedTime)).div(discountDurationInSeconds)).add(baseDiscount);
        }
    }

    // *************************
    // ***** Internal Functions
    // *************************

    function _performStakingForToken(
        uint __tokenId,
        uint __dmmTokenId,
        StakingDuration __duration,
        IAssetIntroducerV1 __assetIntroducerProxy
    ) internal {
        uint stakeAmount = getStakeAmountByTokenIdAndDmmTokenId(__tokenId, __dmmTokenId);
        address mToken = IDmmController(__assetIntroducerProxy.dmmController()).getDmmTokenAddressByDmmTokenId(__dmmTokenId);
        IERC20(mToken).safeTransferFrom(msg.sender, address(this), stakeAmount);
        uint64 unlockTimestamp = uint64(block.timestamp) + mapDurationEnumToSeconds(__duration);
        _userToStakesMap[msg.sender].push(UserStake({
        isWithdrawn : false,
        unlockTimestamp : unlockTimestamp,
        mToken : mToken,
        amount : stakeAmount,
        tokenId : __tokenId
        }));
        emit UserBeginStaking(msg.sender, __tokenId, mToken, stakeAmount, unlockTimestamp);
    }

    function _getStakeAmountByDmmTokenId(
        uint __dmmTokenId,
        uint __priceUsd
    ) internal view returns (uint) {
        IDmmController controller = IDmmController(IAssetIntroducerV1(_assetIntroducerProxy).dmmController());
        address dmmToken = controller.getDmmTokenAddressByDmmTokenId(__dmmTokenId);
        address underlyingToken = controller.getUnderlyingTokenForDmm(dmmToken);
        uint usdPricePerToken = controller.underlyingTokenValuator().getTokenValue(underlyingToken, ONE_ETH);
        uint numberOfDmmTokensStandardized = __priceUsd.mul(ONE_ETH).div(usdPricePerToken).mul(ONE_ETH).div(controller.getExchangeRate(dmmToken));
        uint8 decimals = IERC20WithDecimals(dmmToken).decimals();
        if (decimals > 18) {
            return numberOfDmmTokensStandardized.mul(10 ** uint(decimals - 18));
        } else if (decimals < 18) {
            return numberOfDmmTokensStandardized.div(10 ** uint(18 - decimals));
        } else {
            return numberOfDmmTokensStandardized;
        }
    }

}