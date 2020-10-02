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

import "./DMGYieldFarmingV2Lib.sol";

interface IDMGYieldFarmingV2 {

    // ////////////////////
    // Admin Events
    // ////////////////////

    event GlobalProxySet(address indexed proxy, bool isTrusted);

    event TokenAdded(address indexed token, address indexed underlyingToken, uint8 underlyingTokenDecimals, uint16 points, uint16 fees);
    event TokenRemoved(address indexed token);

    event FarmSeasonBegun(uint indexed seasonIndex, uint dmgAmount);
    event FarmSeasonEnd(uint indexed seasonIndex, address dustRecipient, uint dustyDmgAmount);

    event DmgGrowthCoefficientSet(uint coefficient);
    event RewardPointsSet(address indexed token, uint16 points);

    event UnderlyingTokenValuatorChanged(address newUnderlyingTokenValutor, address oldUnderlyingTokenValutor);
    event UniswapV2RouterChanged(address newUniswapV2Router, address oldUniswapV2Router);
    event FeesChanged(address indexed token, uint16 feeAmount);
    event TokenTypeChanged(address indexed token, DMGYieldFarmingV2Lib.TokenType tokenType);

    // ////////////////////
    // User Events
    // ////////////////////

    event Approval(address indexed user, address indexed spender, bool isTrusted);

    event BeginFarming(address indexed owner, address indexed token, uint depositedAmount);
    event EndFarming(address indexed owner, address indexed token, uint withdrawnAmount, uint earnedDmgAmount);

    event WithdrawOutOfSeason(address indexed owner, address indexed token, address indexed recipient, uint amount);

    event Harvest(address indexed owner, address indexed token, uint earnedDmgAmount);

    /**
     * @param tokenAmountToConvert  The amount of `token` to be converted to DMG and burned.
     * @param dmgAmountBurned       The amount of DMG burned after `tokenAmountToConvert` was converted to DMG.
     */
    event HarvestFeePaid(address indexed owner, address indexed token, uint tokenAmountToConvert, uint dmgAmountBurned);

    // ////////////////////
    // Admin Functions
    // ////////////////////

    /**
     * Sets the `proxy` as a trusted contract, allowing it to interact with the user, on the user's behalf.
     *
     * @param proxy     The address that can interact on the user's behalf.
     * @param isTrusted True if the proxy is trusted or false if it's not (should be removed).
     */
    function approveGloballyTrustedProxy(
        address proxy,
        bool isTrusted
    ) external;

    /**
     * @return  true if the provided `proxy` is globally trusted and may interact with the yield farming contract on a
     *          user's behalf or false otherwise.
     */
    function isGloballyTrustedProxy(
        address proxy
    ) external view returns (bool);

    /**
     * @param token                     The address of the token to be supported for farming.
     * @param underlyingToken           The token to which this token is pegged. IE a Uniswap-V2 LP equity token for
     *                                  DAI-mDAI has an underlying token of DAI.
     * @param underlyingTokenDecimals   The number of decimals that the `underlyingToken` has.
     * @param points                    The amount of reward points for the provided token.
     * @param fees                      The fees to be paid in `underlyingToken` when the user performs a harvest.
     * @param tokenType                 The type of token that is being added. Used for unwrapping it and paying harvest
      *                                 fees.
     */
    function addAllowableToken(
        address token,
        address underlyingToken,
        uint8 underlyingTokenDecimals,
        uint16 points,
        uint16 fees,
        DMGYieldFarmingV2Lib.TokenType tokenType
    ) external;

    /**
     * @param token The address of the token that will be removed from farming.
     */
    function removeAllowableToken(
        address token
    ) external;

    /**
     * Changes the reward points for the provided tokens. Reward points are a weighting system that enables certain
     * tokens to accrue DMG faster than others, allowing the protocol to prioritize certain deposits. At the start of
     * season 1, mETH had points of 100 (equalling 1) and the stablecoins had 200, doubling their weight against mETH.
     */
    function setRewardPointsByTokens(
        address[] calldata tokens,
        uint16[] calldata points
    ) external;

    /**
     * Sets the DMG growth coefficient to use the new parameter provided. This variable is used to define how much
     * DMG is earned every second, for each dollar being farmed accrued.
     */
    function setDmgGrowthCoefficient(
        uint dmgGrowthCoefficient
    ) external;

    /**
     * Begins the farming process so users that accumulate DMG by locking tokens can start for this rotation. Calling
     * this function increments the currentSeasonIndex, starting a new season. This function reverts if there is
     * already an active season.
     *
     * @param dmgAmount The amount of DMG that will be used to fund this campaign.
     */
    function beginFarmingSeason(
        uint dmgAmount
    ) external;

    /**
     * Ends the active farming process if the admin calls this function. Otherwise, anyone may call this function once
     * all DMG have been drained from the contract.
     *
     * @param dustRecipient The recipient of any leftover DMG in this contract, when the campaign finishes.
     */
    function endActiveFarmingSeason(
        address dustRecipient
    ) external;

    function setUnderlyingTokenValuator(
        address underlyingTokenValuator
    ) external;

    function setWethToken(
        address weth
    ) external;

    function setUniswapV2Router(
        address uniswapV2Router
    ) external;

    function setFeesByTokens(
        address[] calldata tokens,
        uint16[] calldata fees
    ) external;

    function setTokenTypeByToken(
        address token,
        DMGYieldFarmingV2Lib.TokenType tokenType
    ) external;

    /**
     * Used to initialize the protocol, mid-season since the Protocol kept track of DMG balances differently on v1.
     */
    function initializeDmgBalance() external;

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
    function isApproved(
        address user,
        address spender
    ) external view returns (bool);

    /**
     * Begins a farm by transferring `amount` of `token` from `user` to this contract and adds it to the balance of
     * `user`. `user` must be either 1) msg.sender or 2) a wallet who has approved msg.sender as a proxy; else this
     * function reverts. `funder` must be either 1) msg.sender or `user`; else this function reverts.
     */
    function beginFarming(
        address user,
        address funder,
        address token,
        uint amount
    ) external;

    /**
     * Ends a farm by transferring all of `token` deposited by `from` to `recipient`, from this contract, as well as
     * all earned DMG for farming `token` to `recipient`. `from` must be either 1) msg.sender or 2) an approved
     * proxy; else this function reverts.
     *
     * @return  The amount of `token` withdrawn and the amount of DMG earned for farming. Both values are sent to
     *          `recipient`.
     */
    function endFarmingByToken(
        address from,
        address recipient,
        address token
    ) external returns (uint, uint);

    /**
     * Withdraws all of `msg.sender`'s tokens from the farm to `recipient`. This function reverts if there is an active
     * farm. `user` must be either 1) msg.sender or 2) an approved proxy; else this function reverts.
     *
     * @return  Each token and the amount of each withdrawn.
     */
    function withdrawAllWhenOutOfSeason(
        address user,
        address recipient
    ) external returns (address[] memory, uint[] memory);

    /**
     * Withdraws all of `user` `token` from the farm to `recipient`. This function reverts if there is an active farm and the token is NOT removed.
     * `user` must be either 1) msg.sender or 2) an approved proxy; else this function reverts.
     *
     * @return The amount of tokens sent to `recipient`
     */
    function withdrawByTokenWhenOutOfSeason(
        address user,
        address recipient,
        address token
    ) external returns (uint);

    /**
     * @return  The amount of DMG that this owner has earned in the active farm. If there are no active season, this
     *          function returns `0`.
     */
    function getRewardBalanceByOwner(
        address owner
    ) external view returns (uint);

    /**
     * @return  The amount of DMG that this owner has earned in the active farm for the provided token. If there is no
     *          active season, this function returns `0`.
     */
    function getRewardBalanceByOwnerAndToken(
        address owner,
        address token
    ) external view returns (uint);

    /**
     * @return  The amount of `token` that this owner has deposited into this contract. The user may withdraw this
     *          non-zero balance by invoking `endFarming` or `endFarmingByToken` if there is an active farm. If there is
     *          NO active farm, the user may withdraw his/her funds by invoking
     */
    function balanceOf(
        address owner,
        address token
    ) external view returns (uint);

    /**
     * @return  The most recent timestamp at which the `owner` deposited `token` into the yield farming contract for
     *          the current season. If there is no active season, this function returns `0`.
     */
    function getMostRecentDepositTimestampByOwnerAndToken(
        address owner,
        address token
    ) external view returns (uint64);

    /**
     * @return  The most recent indexed amount of DMG earned by the `owner` for the deposited `token` which is being
     *          farmed for the most-recent season. If there is no active season, this function returns `0`.
     */
    function getMostRecentIndexedDmgEarnedByOwnerAndToken(
        address owner,
        address token
    ) external view returns (uint);

    /**
     * Harvests any earned DMG from the provided token for the given user and farmable token. User must be either
     * 1) `msg.sender` or 2) an approved proxy for `user`. The DMG is sent to `recipient`.
     */
    function harvestDmgByUserAndToken(
        address user,
        address recipient,
        address token
    ) external returns (uint);

    /**
     * Harvests any earned DMG from the provided token for the given user and farmable token. User must be either
     * 1) `msg.sender` or 2) an approved proxy for `user`. The DMG is sent to `recipient`.
     */
    function harvestDmgByUser(
        address user,
        address recipient
    ) external returns (uint);

    /**
     * Gets the underlying token for the corresponding farmable token.
     */
    function getUnderlyingTokenByFarmToken(
        address farmToken
    ) external view returns (address);

    // ////////////////////
    // Misc Functions
    // ////////////////////

    /**
     * @return  The tokens that the farm supports.
     */
    function getFarmTokens() external view returns (address[] memory);

    /**
     * @return  True if the provided token is supported for farming, or false if it's not.
     */
    function isSupportedToken(address token) external view returns (bool);

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
     * @return  The amount of points that the provided token earns for each unit of token deposited. Defaults to `1`
     *          if the provided `token` does not exist or does not have a special weight. This number is `2` decimals.
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

    function underlyingTokenValuator() external view returns (address);

    function weth() external view returns (address);

    function uniswapV2Router() external view returns (address);

    function getFeesByToken(address token) external view returns (uint16);

}