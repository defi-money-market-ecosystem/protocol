pragma solidity ^0.5.0;

import "../interfaces/IOffChainAssetValuator.sol";

contract OffChainAssetValuatorImplV1 is IOffChainAssetValuator {

    function getOffChainAssetsValue() public returns (uint) {
        return 0;
    }

}
