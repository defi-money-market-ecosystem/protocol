pragma solidity ^0.5.0;

import "./interfaces/ICollateralValuator.sol";

contract DmmCollateralValuator is ICollateralValuator {

    constructor() public {
    }

    function getCollateralValue() public view returns (uint) {
        return 1e18;
    }

}
