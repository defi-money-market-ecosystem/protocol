pragma solidity ^0.5.0;

import "../interfaces/IUsdAggregator.sol";

contract EthUsdAggregatorMock is IUsdAggregator {

    function currentAnswer() public view returns (uint) {
        // $134.87
        return 13487000000;
    }

}