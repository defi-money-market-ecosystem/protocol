pragma solidity ^0.5.0;

import "../interfaces/ICollateralValuator.sol";

contract ChainlinkCollateralValuator is ICollateralValuator {

    function getCollateralValue() public view returns (uint) {
        // TODO - interact with the Chainlink contract to get the system's collateral's aggregate value.
        return 1e18;
    }

}