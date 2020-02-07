pragma solidity ^0.5.0;

import "../libs/Blacklistable.sol";
import "../libs/ERC20.sol";

contract ERC20Mock is ERC20, Pausable, Blacklistable {

    function pausable() public view returns (address) {
        return address(this);
    }

    function blacklistable() public view returns (address) {
        return address(this);
    }

}
