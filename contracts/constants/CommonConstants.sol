pragma solidity ^0.5.0;

import "../libs/DmmTokenLibrary.sol";

contract CommonConstants {

    using DmmTokenLibrary for *;

    uint public EXCHANGE_RATE_BASE_RATE = DmmTokenLibrary.getExchangeRateBaseRate();
    uint public INTEREST_RATE_BASE = DmmTokenLibrary.getInterestRateBase();
    uint public SECONDS_IN_YEAR = DmmTokenLibrary.getSecondsInYear();

}