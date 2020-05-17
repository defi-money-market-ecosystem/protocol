pragma solidity ^0.5.0;

library SafeBitMath {

    function safe64(uint n, string memory errorMessage) internal pure returns (uint64) {
        require(n < 2 ** 64, errorMessage);
        return uint64(n);
    }

    function safe128(uint n, string memory errorMessage) internal pure returns (uint128) {
        require(n < 2 ** 128, errorMessage);
        return uint128(n);
    }

    function add128(uint128 a, uint128 b, string memory errorMessage) internal pure returns (uint128) {
        uint128 c = a + b;
        require(c >= a, errorMessage);
        return c;
    }

    function sub128(uint128 a, uint128 b, string memory errorMessage) internal pure returns (uint128) {
        require(b <= a, errorMessage);
        return a - b;
    }

}
