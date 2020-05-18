pragma solidity ^0.5.0;

import "../interfaces/IUsdAggregatorV2.sol";

contract DaiUsdAggregatorMock is IUsdAggregatorV2 {

    function latestAnswer() public view returns (uint) {
        // $1.006
        return 100600000;
    }

}