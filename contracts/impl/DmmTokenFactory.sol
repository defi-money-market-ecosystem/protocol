pragma solidity ^0.5.0;

import "./DmmEther.sol";
import "../interfaces/IDmmToken.sol";
import "../interfaces/IDmmTokenFactory.sol";

contract DmmTokenFactory is Context, IDmmTokenFactory, Ownable {

    constructor() public {
    }

    function deployToken(
        string memory symbol,
        string memory name,
        uint8 decimals,
        uint minMintAmount,
        uint minRedeemAmount,
        uint totalSupply,
        address controller
    ) public onlyOwner returns (IDmmToken) {
        DmmToken token = new DmmToken(
            symbol,
            name,
            decimals,
            minMintAmount,
            minRedeemAmount,
            totalSupply,
            controller
        );
        token.transferOwnership(_msgSender());
        return token;
    }

}
