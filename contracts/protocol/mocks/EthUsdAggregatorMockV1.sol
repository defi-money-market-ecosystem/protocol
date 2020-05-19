pragma solidity ^0.5.0;

import "../interfaces/IUsdAggregatorV1.sol";

contract EthUsdAggregatorMockV1 is IUsdAggregatorV1 {

    function currentAnswer() public view returns (uint) {
        // $134.87
        return 13487000000;
    }

}