/*
 * Copyright 2020 DMM Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


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
