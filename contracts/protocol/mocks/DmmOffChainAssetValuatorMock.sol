pragma solidity ^0.5.0;

import "../interfaces/IOffChainAssetValuator.sol";

contract DmmOffChainAssetValuatorMock is IOffChainAssetValuator {

    uint private _collateralValue = 10000000e18;

    constructor() public {
    }

    function getOffChainAssetsValue() public view returns (uint) {
        return _collateralValue;
    }

    function setCollateralValue(uint collateralValue) public {
        _collateralValue = collateralValue;
    }

}
