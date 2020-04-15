pragma solidity ^0.5.0;

import "../../utils/Blacklistable.sol";
import "../../utils/ERC20.sol";

contract ERC20Mock is ERC20, Blacklistable {

    function pausable() public view returns (address) {
        return address(this);
    }

    function blacklistable() public view returns (Blacklistable) {
        return Blacklistable(address(this));
    }

    function setBalance(address recipient, uint amount) public {
        mintToThisContract(amount);
        _transfer(address(this), recipient, amount);
    }

}
