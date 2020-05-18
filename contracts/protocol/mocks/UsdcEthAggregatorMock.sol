pragma solidity ^0.5.0;

import "../interfaces/IUsdAggregatorV2.sol";

contract UsdcEthAggregatorMock is IUsdAggregatorV2 {

    function latestAnswer() public view returns (uint) {
        // Ξ 0.004674771
        return 4674771000000000;
    }

}