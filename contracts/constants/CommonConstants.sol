pragma solidity ^0.5.0;

import "../libs/DmmTokenLibrary.sol";

contract CommonConstants {

    using DmmTokenLibrary for *;

    uint public EXCHANGE_RATE_BASE_RATE = DmmTokenLibrary.getExchangeRateBaseRate();

}