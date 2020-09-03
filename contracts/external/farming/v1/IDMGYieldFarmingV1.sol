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

    event TokenAdded(address indexed token, address indexed underlyingToken, uint8 underlyingTokenDecimals, uint16 points);
    event TokenRemoved(address indexed token);

    event FarmCampaignBegun(uint indexed seasonIndex, uint dmgAmount);
    event FarmCampaignEnd(uint indexed seasonIndex, address dustRecipient, uint dustyDmgAmount);

    event DmgGrowthCoefficientSet(uint coefficient);
    event RewardPointsSet(address indexed token, uint16 points);

    event Approval(address indexed user, address indexed spender, bool isTrusted);

    event BeginFarming(address indexed owner, address indexed token, uint depositedAmount);
    event EndFarming(address indexed owner, address indexed token, uint withdrawnAmount, uint earnedDmgAmount);

    event WithdrawOutOfSeason(address indexed owner, address indexed token, address indexed recipient, uint amount);

    // ////////////////////
    // Admin Functions
    // ////////////////////

    /**
     * @param token                     The address of the token to be supported for farming.
     * @param underlyingToken           The token to which this token is pegged. IE a Uniswap-V2 LP equity token for
     *                                  DAI-mDAI has an underlying token of DAI.
     * @param underlyingTokenDecimals   The number of decimals that the `underlyingToken` has.
     * @param points                    The amount of reward points for the provided token.
     */
    function addAllowableToken(address token, address underlyingToken, uint8 underlyingTokenDecimals, uint16 points) external;

    /**
     * @param token     The address of the token that will be removed from farming.
     */
    function removeAllowableToken(address token) external;

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

    /**
     * Begins the farming process so users that accumulate DMG by locking mTokens can start for this rotation. Calling
     * this function increments the currentSeasonIndex, starting a new season. This function reverts if there is
     * already an active season.
     *
     * @param dmgAmount The amount of DMG that will be used to fund this campaign.
     */
    function beginFarmingCampaign(uint dmgAmount) external;

    /**
     * Ends the active farming process if the admin calls this function. Otherwise, anyone may call this function once
     * all DMG have been drained from the contract.
     *
     * @param dustRecipient The recipient of any leftover DMG in this contract, when the campaign finishes.
     */
    function endActiveFarmingCampaign(address dustRecipient) external;

    // ////////////////////
    // Misc Functions
    // ////////////////////

    /**
     * @return  The tokens that the farm supports.
     */
    function getFarmTokens() external view returns (address[] memory);

    /**
     * @return  True if there is an active season for farming, or false if there isn't one.
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
    function dmgGrowthCoefficient() external view returns (uint);

    /**
     * @return  The amount of points that the provided mToken earns for each unit of mToken deposited. Defaults to `1`
     *          if the provided `token` does not exist or does not have a special weight.
     */
    function getRewardPointsByToken(address token) external view returns (uint16);

    /**
     * @return  The number of decimals that the underlying token has.
     */
    function getTokenDecimalsByToken(address token) external view returns (uint8);

    /**
     * @return  The index into the array returned from `getFarmTokens`, plus 1. 0 if the token isn't found. If the
     *          index returned is non-zero, subtract 1 from it to get the real index into the array.
     */
    function getTokenIndexPlusOneByToken(address token) external view returns (uint);

    // ////////////////////
    // User Functions
    // ////////////////////

    /**
     * Approves the spender from `msg.sender` to transfer funds into the contract on the user's behalf. If `isTrusted`
     * is marked as false, removes the spender.
     */
    function approve(address spender, bool isTrusted) external;

    /**
     * True if the `spender` can transfer tokens on the user's behalf to this contract.
     */
    function isApproved(address user, address spender) external view returns (bool);

    /**
     * Begins a farm by transferring `amount` mTokens (with DMM token ID `token`) from `user` to this
     * contract and adds it to the balance of `user`. If `msg.sender` is not `user`, the
     */
    function beginFarming(address user, address token, uint amount) external;

    /**
     * Ends a farm by transferring all of `token` deposited by `from` to `recipient`, from this contract, as well as
     * all earned DMG for farming `token` to `recipient`. `from` must be either 1) msg.sender or 2) an approved
     * proxy; else this function reverts.
     *
     * @return  The amount of `token` withdrawn and the amount of DMG earned for farming. Both values are sent to
     *          `recipient`.
     */
    function endFarmingByToken(address from, address recipient, address token) external returns (uint, uint);

    /**
     * Withdraws all of `msg.sender`'s tokens from the farm to `recipient`. This function reverts if there is an active
     * farm. `user` must be either 1) msg.sender or 2) an approved proxy; else this function reverts.
     */
    function withdrawAllWhenOutOfSeason(address user, address recipient) external;

    /**
     * Withdraws all of `user` `token` from the farm to `recipient`. This function reverts if there is an active farm and the token is NOT removed.
     * `user` must be either 1) msg.sender or 2) an approved proxy; else this function reverts.
     *
     * @return The amount of tokens sent to `recipient`
     */
    function withdrawByTokenWhenOutOfSeasonOrTokenIsRemoved(
        address user,
        address recipient,
        address token
    ) external returns (uint);

    /**
     * @return  The amount of DMG that this owner has earned in the active farm. If there are no active season, this
     *          function returns `0`.
     */
    function getRewardBalanceByOwner(address owner) external view returns (uint);

    /**
     * @return  The amount of DMG that this owner has earned in the active farm for the provided token. If there is no
     *          active season, this function returns `0`.
     */
    function getRewardBalanceByOwnerAndToken(address owner, address token) external view returns (uint);

    /**
     * @return  The amount of `token` that this owner has deposited into this contract. The user may withdraw this
     *          non-zero balance by invoking `endFarming` or `endFarmingByToken` if there is an active farm. If there is
     *          NO active farm, the user may withdraw his/her funds by invoking
     */
    function balanceOf(address owner, address token) external view returns (uint);

    /**
     * @return  The most recent timestamp at which the `owner` deposited `token` into the yield farming contract for
     *          the current season. If there is no active season, this function returns `0`.
     */
    function getMostRecentDepositTimestampByOwnerAndToken(address owner, address token) external view returns (uint64);

    /**
     * @return  The most recent indexed amount of DMG earned by the `owner` for the deposited `token` which is being
     *          farmed for the most-recent season. If there is no active season, this function returns `0`.
     */
    function getMostRecentIndexedDmgEarnedByOwnerAndToken(address owner, address token) external view returns (uint);

}
