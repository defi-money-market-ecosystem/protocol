pragma solidity ^0.5.0;

interface ICollateralValuator {

    event CollateralValueUpdated(uint newCollateralValue);

    /**
     * @dev Gets the DMM ecosystem's collateral's value from Chainlink's on-chain data feed.
     *
     * @return The value of the ecosystem's collateral, as a number with 18 decimals
     */
    function getCollateralValue() external view returns (uint);

}
