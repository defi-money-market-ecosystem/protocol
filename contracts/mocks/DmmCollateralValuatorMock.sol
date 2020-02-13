pragma solidity ^0.5.0;

import "../interfaces/ICollateralValuator.sol";

contract DmmCollateralValuatorMock is ICollateralValuator {

    uint private _collateralValue = 1e25;

    constructor() public {
    }

    function getCollateralValue() public view returns (uint) {
        return _collateralValue;
    }

    function setCollateralValue(uint collateralValue) public {
        _collateralValue = collateralValue;
    }

}
