pragma solidity ^0.5.0;

import "../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../interfaces/IOffChainAssetValuator.sol";

contract OffChainAssetValuatorImplV1 is IOffChainAssetValuator, Ownable {

    function getOffChainAssetsValue() public view returns (uint) {
        return 0;
    }

}
