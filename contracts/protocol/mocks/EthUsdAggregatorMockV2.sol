pragma solidity ^0.5.0;

import "../interfaces/IUsdAggregatorV2.sol";

contract EthUsdAggregatorMockV2 is IUsdAggregatorV2 {

    function latestAnswer() public view returns (uint) {
        // $134.87
        return 13487000000;
    }

}