pragma solidity ^0.5.0;

interface InterestRateInterface {

    /**
      * @dev Returns the current interest rate for the given DMMA and corresponding total supply & active supply
      *
      * @param dmmTokenId The DMMA whose interest should be retrieved
      * @param totalSupply The total supply fot he DMM token
      * @param activeSupply The supply that's currently being lent by users
      * @return The interest rate in APY, which is a number with 18 decimals
      */
    function getInterestRate(uint dmmTokenId, uint totalSupply, uint activeSupply) external view returns (uint);

}
