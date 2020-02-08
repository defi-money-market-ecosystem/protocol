pragma solidity ^0.5.0;

import "../libs/ICollateralValuator.sol";

contract CollateralValuatorMockImpl is ICollateralValuator {

    function getCollateralValue() public view returns (uint) {
        // 10m
        return 10_000_000 * 1e18;
    }

}
