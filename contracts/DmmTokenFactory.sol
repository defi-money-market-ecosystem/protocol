pragma solidity ^0.5.0;

import "./DmmToken.sol";
import "./interfaces/IDmmToken.sol";
import "./interfaces/IDmmTokenFactory.sol";

contract DmmTokenFactory is Context, IDmmTokenFactory {

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
    ) public returns (IDmmToken) {
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
