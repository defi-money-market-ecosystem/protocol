pragma solidity ^0.5.0;

import "../interfaces/IUsdAggregator.sol";

contract DaiUsdAggregatorMock is IUsdAggregator {

    function currentAnswer() public view returns (uint) {
        // $1.006
        return 100600000;
    }

}