pragma solidity ^0.5.0;

import "./DmmEther.sol";
import "../interfaces/IDmmTokenFactory.sol";

contract DmmEtherFactory is Context, IDmmTokenFactory, Ownable {

    address public wethToken;

    constructor(address _wethToken) public {
        wethToken = _wethToken;
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
        DmmEther token = new DmmEther(
            wethToken,
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