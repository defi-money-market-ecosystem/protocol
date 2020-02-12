pragma solidity ^0.5.0;

import "./IDmmToken.sol";

interface IDmmTokenFactory {

    function deployToken(
        string calldata symbol,
        string calldata name,
        uint8 decimals,
        uint minMintAmount,
        uint minRedeemAmount,
        uint totalSupply,
        address controller
    ) external returns (IDmmToken);

}
