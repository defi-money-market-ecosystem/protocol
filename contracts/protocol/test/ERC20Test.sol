pragma solidity ^0.5.0;

import "../mocks/ERC20Mock.sol";

contract ERC20Test is ERC20Mock {

    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

}
