pragma solidity ^0.5.0;

import "./DmmToken.sol";
import "./DmmEther.sol";
import "../interfaces/IDmmToken.sol";
import "../interfaces/IDmmTokenFactory.sol";

contract DmmTokenFactory is Context, IDmmTokenFactory {

    address public wethToken;

    constructor(address _wethToken) public {
        wethToken = _wethToken;
    }

    function deployToken(
        address underlyingToken,
        string memory symbol,
        string memory name,
        uint8 decimals,
        uint minMintAmount,
        uint minRedeemAmount,
        uint totalSupply,
        address controller
    ) public returns (IDmmToken) {
        DmmToken token;
        if (underlyingToken == wethToken) {
            token = new DmmEther(
                wethToken,
                symbol,
                name,
                decimals,
                minMintAmount,
                minRedeemAmount,
                totalSupply,
                controller
            );
        } else {
            token = new DmmToken(
                symbol,
                name,
                decimals,
                minMintAmount,
                minRedeemAmount,
                totalSupply,
                controller
            );
        }

        token.transferOwnership(_msgSender());
        return token;
    }

}
