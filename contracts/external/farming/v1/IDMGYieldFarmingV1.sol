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

/**
 * The interface for DMG "Yield Farming" - A process through which users may earn DMG by locking up their mTokens.
 *
 * Yield farming in the DMM Ecosystem entails "rotation periods" in which a campaign is active, in order to incentivize
 * deposits of underlying tokens into the protocol.
 */
interface IDMGYieldFarmingV1 {

    // ////////////////////
    // Events
    // ////////////////////

    event FarmCampaignBegun(uint indexed campaignIndex, uint dmgAmount);
    event FarmCampaignEnd(uint indexed campaignIndex, address dustRecipient);

    event DmgGrowthCoefficientSet(uint coefficient);
    event RewardPointsSet(address indexed token, uint16 points);

    event BeginFarming(address indexed owner, address indexed token, uint depositedAmount);
    event EndFarming(address indexed owner, address indexed token, uint withdrawnAmount, uint earnedDmgAmount);

    event WithdrawOutOfSeason(address indexed owner, address indexed token, uint amount);

    // ////////////////////
    // Admin Functions
    // ////////////////////

    /**
     * @param token             The address of the token to be supported for farming.
     * @param underlyingToken   The token to which this token is pegged. IE a Uniswap-V2 LP equity token for DAI-mDAI
     *                          has an underlying token of DAI.
     * @param points            The amount of reward points for the provided token.
     */
    function addAllowableToken(address token, address underlyingToken, uint16 points) external;

    /**
     * @param token     The address of the token that will be removed from farming.
     */
    function removeAllowableToken(address token) external;

    /**
     * Begins the farming process so users that accumulate DMG by locking mTokens can start for this rotation. Calling
     * this function increments the currentFarmIndex, ending a previous campaign and starting a new one.
     *
     * @param funder    The address of the entity that will fund this yield farming campaign.
     * @param dmgAmount The amount of DMG that will be used to fund this campaign.
     */
    function beginFarmingCampaign(address funder, uint dmgAmount) external;

    /**
     * Ends the active farming process if the admin calls this function. Otherwise, anyone may call this function once
     * all DMG have been drained from the contract.
     *
     * @param dustRecipient The recipient of any leftover DMG in this contract, when the campaign finishes.
     */
    function endActiveFarmingCampaign(address dustRecipient) external;

    /**
     * Changes the reward points for the provided token. Reward points are a weighting system that enables certain
     * mTokens to accrue DMG faster than others, allowing the protocol to prioritize certain deposits.
     */
    function setRewardPointsByToken(address token, uint16 points) external;

    /**
     * Sets the DMG growth coefficient to use the new parameter provided. This variable is used to define how much
     * DMG is earned every second, for each point accrued.
     */
    function setDmgGrowthCoefficient(uint dmgGrowthCoefficient) external;

    // ////////////////////
    // Misc Functions
    // ////////////////////

    /**
     * @return  The tokens that the farm supports.
     */
    function getFarmTokens() external view returns (address[] memory);

    /**
     * @return  True if there is an active farm, or false if there isn't one.
     */
    function isFarmActive() external view returns (bool);

    /**
     * The address that acts as a "secondary" owner with quicker access to function calling than the owner. Typically,
     * this is the DMMF.
     */
    function guardian() external view returns (address);

    /**
     * @return The DMG token.
     */
    function dmgToken() external view returns (address);

    /**
     * @return  The growth coefficient for earning DMG while farming. Each unit represents how much DMG is earned per
     *          point
     */
    function dmgGrowthEfficient() external view returns (uint);

    /**
     * @return  The amount of points that the provided mToken earns for each unit of mToken deposited. Defaults to `1`
     *          if the provided `token` does not exist or does not have a special weight.
     */
    function getRewardPointsByToken(address token) external view returns (uint16);

    // ////////////////////
    // User Functions
    // ////////////////////

    /**
     * Begins a farm by transferring `amount` mTokens (with DMM token ID `token`) from `msg.sender` to this
     * contract.
     */
    function beginFarming(address token, uint amount) external;

    /**
     * Ends a farm by transferring all mTokens deposited by `msg.sender` to `msg.sender`, from this contract, as well as
     * all earned DMG for farming all deposited mTokens.
     *
     * @return  The amount of DMG earned for farming. This value is sent to `msg.sender`.
     */
    function endFarming() external returns (uint);

    /**
     * Ends a farm by transferring all mTokens (with DMM token ID `token`) deposited by `msg.sender` to
     * `msg.sender`, from this contract, as well as all earned DMG for farming `token`.
     *
     * @return  The amount of mTokens withdrawn and the amount of DMG earned for farming. Both values are sent to
     *          `msg.sender`.
     */
    function endFarmingByToken(address token) external returns (uint, uint);

    /**
     * Withdraws all of `msg.sender`'s mTokens from the farm. This function reverts if there is an active farm.
     */
    function withdrawAllWhenOutOfSeason() external;

    /**
     * Withdraws all of `msg.sender` `token` from the farm. This function reverts if there is an active farm.
     */
    function withdrawByTokenWhenOutOfSeason(address token) external;

    /**
     * @return  The amount of DMG that this owner has earned in the active farm. If there are no active farms, this
     *          function returns `0`.
     */
    function rewardBalanceOf(address owner) external view returns (uint);

    /**
     * @return  The amount of `token` that this owner has deposited into this contract. The user may withdraw this
     *          non-zero balance by invoking `endFarming` or `endFarmingByToken` if there is an active farm. If there is
     *          NO active farm, the user may withdraw his/her funds by invoking
     */
    function balanceOf(address owner, address token) external view returns (uint);

}
