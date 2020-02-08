pragma solidity ^0.5.0;

interface IUnderlyingTokenValuator {

    /**
      * @dev Gets the tokens value in terms of USD.
      *
      * @return The value of the `amount` of `token`, as a number with 18 decimals
      */
    function getTokenValue(address token, uint amount) external view returns (uint);

}
