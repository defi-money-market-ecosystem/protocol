pragma solidity ^0.5.0;

/**
 * @dev Gets the USD value of a currency with 8 decimals.
 */
interface IUsdAggregatorV2 {

    /**
     * @return The USD value of a currency, with 8 decimals.
     */
    function latestAnswer() external view returns (uint);

}