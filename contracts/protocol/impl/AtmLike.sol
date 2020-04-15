pragma solidity ^0.5.0;

import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract AtmLike is Ownable {

    using SafeERC20 for IERC20;

    function deposit(address token, uint amount) public onlyOwner {
        IERC20(token).safeTransferFrom(_msgSender(), address(this), amount);
    }

    function withdraw(address token, address recipient, uint amount) public onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
    }

}
