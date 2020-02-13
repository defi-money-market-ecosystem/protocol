pragma solidity ^0.5.0;

import "../interfaces/IWETH.sol";
import "./ERC20Mock.sol";

contract WETHMock is ERC20Mock, IWETH {

    event Deposit(address indexed sender, uint wad);
    event Withdrawal(address indexed sender, uint wad);

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
        msg.sender.transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

}