pragma solidity ^0.5.0;

library SafeEther {

    function sendEther(address recipient, uint amount) internal {
        sendEther(recipient, amount, "CANNOT_TRANSFER_ETHER");
    }

    function sendEther(address recipient, uint amount, string memory errorMessage) internal {
        (bool success,) = address(uint160(recipient)).call.value(amount)("");
        require(success, errorMessage);
    }

}