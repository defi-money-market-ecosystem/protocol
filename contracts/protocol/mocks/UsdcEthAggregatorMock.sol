pragma solidity ^0.5.0;

import "../interfaces/IUsdAggregator.sol";

contract UsdcEthAggregatorMock is IUsdAggregator {

    function currentAnswer() public view returns (uint) {
        // Ξ 0.004674771
        return 4674771000000000;
    }

}