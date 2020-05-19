pragma solidity ^0.5.0;

import "../interfaces/IWETH.sol";
import "../../utils/AddressUtil.sol";
import "./ERC20Mock.sol";

contract WETHMock is ERC20Mock, IWETH {

    event Deposit(address indexed sender, uint wad);
    event Withdrawal(address indexed sender, uint wad);

    string constant public name = "Wrapped Ether";
    string constant public symbol = "WETH";
    uint8 constant public decimals = 18;

    constructor() public {
    }

    function() external payable {
        deposit();
    }

    function deposit() public payable {
        _balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint wad) public {
        require(_balances[msg.sender] >= wad, "INSUFFICIENT_BALANCE");

        _balances[msg.sender] -= wad;
        AddressUtil.sendETHAndVerify(msg.sender, wad, gasleft());
        emit Withdrawal(msg.sender, wad);
    }

}