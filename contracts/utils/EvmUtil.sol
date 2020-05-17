pragma solidity ^0.5.13;

library EvmUtil {

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }

}
