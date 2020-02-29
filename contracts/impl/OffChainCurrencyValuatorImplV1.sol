pragma solidity ^0.5.0;

import "../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../interfaces/IOffChainCurrencyValuator.sol";

contract OffChainCurrencyValuatorImplV1 is IOffChainCurrencyValuator, Ownable {

    function getOffChainCurrenciesValue() public view returns (uint) {
        return 0;
    }

}
