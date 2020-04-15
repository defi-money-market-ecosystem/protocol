pragma solidity ^0.5.0;

/**
 * Gets the value of any currencies that are residing off-chain, but are NOT yet allocated to a revenue-producing asset.
 */
interface IOffChainCurrencyValuator {

    /**
     * @return The value of the off-chain assets. The number returned uses 18 decimal places.
     */
    function getOffChainCurrenciesValue() external view returns (uint);

}
