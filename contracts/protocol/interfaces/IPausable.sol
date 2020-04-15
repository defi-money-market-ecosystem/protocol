pragma solidity ^0.5.0;

interface IPausable {

    function paused() external view returns (bool);

}
