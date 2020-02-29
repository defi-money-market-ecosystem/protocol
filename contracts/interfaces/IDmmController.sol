pragma solidity ^0.5.0;

import "./InterestRateInterface.sol";
import "../utils/Blacklistable.sol";

interface IDmmController {

    event TotalSupplyIncreased(uint oldTotalSupply, uint newTotalSupply);
    event TotalSupplyDecreased(uint oldTotalSupply, uint newTotalSupply);

    event AdminDeposit(address indexed sender, uint amount);
    event AdminWithdraw(address indexed receiver, uint amount);

    function blacklistable() external view returns (Blacklistable);

    /**
     * @dev Creates a new mToken using the provided data.
     *
     * @param underlyingToken   The token that should be wrapped to create a new DMMA
     * @param symbol            The symbol of the new DMMA, IE mDAI or mUSDC
     * @param name              The name of this token, IE `DMM: DAI`
     * @param decimals          The number of decimals of the underlying token, and therefore the number for this DMMA
     * @param minMintAmount     The minimum amount that can be minted for any given transaction.
     * @param minRedeemAmount   The minimum amount that can be redeemed any given transaction.
     * @param totalSupply       The initial total supply for this market.
     */
    function addMarket(
        address underlyingToken,
        string calldata symbol,
        string calldata name,
        uint8 decimals,
        uint minMintAmount,
        uint minRedeemAmount,
        uint totalSupply
    ) external;

    /**
     * @dev Creates a new mToken using the already-existing token.
     *
     * @param dmmToken          The token that should be added to this controller.
     * @param underlyingToken   The token that should be wrapped to create a new DMMA.
     */
    function addMarketFromExistingDmmToken(
        address dmmToken,
        address underlyingToken
    ) external;

    /**
     * @param newController The new controller who should receive ownership of the provided DMM token IDs.
     */
    function transferOwnershipToNewController(
        address newController
    ) external;

    /**
     * @dev Enables the corresponding DMMA to allow minting new tokens.
     *
     * @param dmmTokenId  The DMMA that should be enabled.
     */
    function enableMarket(uint dmmTokenId) external;

    /**
     * @dev Disables the corresponding DMMA from minting new tokens. This allows the market to close over time, since
     *      users are only able to redeem tokens.
     *
     * @param dmmTokenId  The DMMA that should be disabled.
     */
    function disableMarket(uint dmmTokenId) external;

    /**
     * @dev Sets a new contract that implements the `InterestRateInterface` interface.
     *
     * @param newInterestRateInterface  The new contract that implements the `InterestRateInterface` interface.
     */
    function setInterestRateInterface(address newInterestRateInterface) external;

    /**
     * @dev Sets a new contract that implements the `IOffChainAssetValuator` interface.
     *
     * @param newOffChainAssetValuator The new contract that implements the `IOffChainAssetValuator` interface.
     */
    function setOffChainAssetValuator(address newOffChainAssetValuator) external;

    /**
     * @dev Sets a new contract that implements the `IOffChainAssetValuator` interface.
     *
     * @param newOffChainCurrencyValuator The new contract that implements the `IOffChainAssetValuator` interface.
     */
    function setOffChainCurrencyValuator(address newOffChainCurrencyValuator) external;

    /**
     * @dev Sets a new contract that implements the `UnderlyingTokenValuator` interface
     *
     * @param newUnderlyingTokenValuator The new contract that implements the `UnderlyingTokenValuator` interface
     */
    function setUnderlyingTokenValuator(address newUnderlyingTokenValuator) external;

    /**
     * @dev Allows the owners of the DMM Ecosystem to withdraw funds from a DMMA. These withdrawn funds are then
     *      allocated to real-world assets that will be used to pay interest into the DMMA.
     *
     * @param newMinCollateralization   The new min collateralization (with 18 decimals) at which the DMME must be in
     *                                  order to add to the total supply of DMM.
     */
    function setMinCollateralization(uint newMinCollateralization) external;

    /**
     * @dev Allows the owners of the DMM Ecosystem to withdraw funds from a DMMA. These withdrawn funds are then
     *      allocated to real-world assets that will be used to pay interest into the DMMA.
     *
     * @param newMinReserveRatio   The new ratio (with 18 decimals) that is used to enforce a certain percentage of assets
     *                          are kept in each DMMA.
     */
    function setMinReserveRatio(uint newMinReserveRatio) external;

    /**
     * @dev Increases the max supply for the provided `dmmTokenId` by `amount`. This call reverts with
     *      INSUFFICIENT_COLLATERAL if there isn't enough collateral in the Chainlink contract to cover the controller's
     *      requirements for minimum collateral.
     */
    function increaseTotalSupply(uint dmmTokenId, uint amount) external;

    /**
     * @dev Increases the max supply for the provided `dmmTokenId` by `amount`.
     */
    function decreaseTotalSupply(uint dmmTokenId, uint amount) external;

    /**
     * @dev Allows the owners of the DMM Ecosystem to withdraw funds from a DMMA. These withdrawn funds are then
     *      allocated to real-world assets that will be used to pay interest into the DMMA.
     *
     * @param dmmTokenId        The ID of the DMM token whose underlying will be funded.
     * @param underlyingAmount  The amount underlying the DMM token that will be deposited into the DMMA.
     */
    function adminWithdrawFunds(uint dmmTokenId, uint underlyingAmount) external;

    /**
     * @dev Allows the owners of the DMM Ecosystem to deposit funds into a DMMA. These funds are used to disburse
     *      interest payments and add more liquidity to the specific market.
     *
     * @param dmmTokenId        The ID of the DMM token whose underlying will be funded.
     * @param underlyingAmount  The amount underlying the DMM token that will be deposited into the DMMA.
     */
    function adminDepositFunds(uint dmmTokenId, uint underlyingAmount) external;

    /**
     * @dev Gets the collateralization of the system assuming 1-year's worth of interest payments are due by dividing
     *      the total value of all the collateralized assets plus the value of the underlying tokens in each DMMA by the
     *      aggregate interest owed (plus the principal), assuming each DMMA was at maximum usage.
     *
     * @return  The 1-year collateralization of the system, as a number with 18 decimals. For example
     *          `1010000000000000000` is 101% or 1.01.
     */
    function getTotalCollateralization() external view returns (uint);

    /**
     * @dev Gets the current collateralization of the system assuming by dividing the total value of all the
     *      collateralized assets plus the value of the underlying tokens in each DMMA by the aggregate interest owed
     *      (plus the principal), using the current usage of each DMMA.
     *
     * @return  The active collateralization of the system, as a number with 18 decimals. For example
     *          `1010000000000000000` is 101% or 1.01.
     */
    function getActiveCollateralization() external view returns (uint);

    /**
     * @dev Gets the interest rate from the underlying token, IE DAI or USDC.
     *
     * @return  The current interest rate, represented using 18 decimals. Meaning `65000000000000000` is 6.5% APY or
     *          0.065.
     */
    function getInterestRateByUnderlyingTokenAddress(address underlyingToken) external view returns (uint);

    /**
     * @dev Gets the interest rate from the DMM token, IE DMM: DAI or DMM: USDC.
     *
     * @return  The current interest rate, represented using 18 decimals. Meaning, `65000000000000000` is 6.5% APY or
     *          0.065.
     */
    function getInterestRateByDmmTokenId(uint dmmTokenId) external view returns (uint);

    /**
     * @dev Gets the interest rate from the DMM token, IE DMM: DAI or DMM: USDC.
     *
     * @return  The current interest rate, represented using 18 decimals. Meaning, `65000000000000000` is 6.5% APY or
     *          0.065.
     */
    function getInterestRateByDmmTokenAddress(address dmmToken) external view returns (uint);

    /**
     * @dev Gets the exchange rate from the underlying to the DMM token, such that
     *      `DMM: Token = underlying / exchangeRate`
     *
     * @return  The current exchange rate, represented using 18 decimals. Meaning, `200000000000000000` is 0.2.
     */
    function getExchangeRateByUnderlying(address underlyingToken) external view returns (uint);

    /**
     * @dev Gets the exchange rate from the underlying to the DMM token, such that
     *      `DMM: Token = underlying / exchangeRate`
     *
     * @return  The current exchange rate, represented using 18 decimals. Meaning, `200000000000000000` is 0.2.
     */
    function getExchangeRate(address dmmToken) external view returns (uint);

    /**
     * @dev Gets the DMM token for the provided underlying token. For example, sending DAI returns DMM: DAI.
     */
    function getDmmTokenForUnderlying(address underlyingToken) external view returns (address);

    /**
     * @dev Gets the underlying token for the provided DMM token. For example, sending DMM: DAI returns DAI.
     */
    function getUnderlyingTokenForDmm(address dmmToken) external view returns (address);

    /**
     * @return True if the market is enabled for this DMMA or false if it is not enabled.
     */
    function isMarketEnabledByDmmTokenId(uint dmmTokenId) external view returns (bool);

    /**
     * @return True if the market is enabled for this DMM token (IE DMM: DAI) or false if it is not enabled.
     */
    function isMarketEnabledByDmmTokenAddress(address dmmToken) external view returns (bool);

    /**
     * @return True if the market is enabled for this underlying token (IE DAI) or false if it is not enabled.
     */
    function getTokenIdFromDmmTokenAddress(address dmmTokenAddress) external view returns (uint);

}
