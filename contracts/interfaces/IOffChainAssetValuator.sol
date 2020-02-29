pragma solidity ^0.5.0;

interface IOffChainAssetValuator {

    event AssetsValueUpdated(uint newAssetsValue);

    /**
     * @dev Gets the DMM ecosystem's collateral's value from Chainlink's on-chain data feed.
     *
     * @return The value of the ecosystem's collateral, as a number with 18 decimals
     */
    function getOffChainAssetsValue() external view returns (uint);

}
