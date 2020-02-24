pragma solidity ^0.5.0;

/**
 * Gets the value of any assets that are residing off-chain, but are NOT yet allocated to a revenue-producing asset.
 */
interface IOffChainAssetValuator {

    /**
     * @return The value of the off-chain assets. The number returned uses 18 decimal places.
     */
    function getOffChainAssetsValue() external returns (uint);

}
