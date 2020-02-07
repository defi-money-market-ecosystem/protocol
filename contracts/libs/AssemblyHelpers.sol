pragma solidity ^0.5.12;

contract AssemblyHelpers {

    function chainId() public pure returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

}
