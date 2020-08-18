pragma solidity ^0.5.0;

import "../interfaces/IUsdAggregatorV2.sol";

contract UsdtEthAggregatorMock is IUsdAggregatorV2 {

    function latestAnswer() public view returns (uint) {
        // Ξ 0.004674780
        return 4674780000000000;
    }

}