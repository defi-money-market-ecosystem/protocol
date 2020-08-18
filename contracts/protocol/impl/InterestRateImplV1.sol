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

import "../interfaces/InterestRateInterface.sol";

contract InterestRateImplV1 is InterestRateInterface {

    constructor() public {
    }

    function getInterestRate(uint dmmTokenId, uint totalSupply, uint activeSupply) external view returns (uint) {
        // 0.0625 or 6.25%
        return 62500000000000000;
    }

}
