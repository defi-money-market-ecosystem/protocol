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
pragma experimental ABIEncoderV2;

import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/IAssetIntroducerDiscount.sol";

import "../AssetIntroducerData.sol";

contract AssetIntroducerDiscountV1 is IAssetIntroducerDiscount {

    using SafeMath for uint;

    function getAssetIntroducerDiscount(
        AssetIntroducerData.DiscountStruct memory data
    ) public view returns (uint) {
        uint diff = block.timestamp.sub(data.initTimestamp);
        // 18 months or 540 days
        uint discountDurationInSeconds = 86400 * 30 * 18;
        if (diff > discountDurationInSeconds) {
            // The discount expired
            return 0;
        } else {
            // Discount is 90% at t=0
            uint originalDiscount = 0.9 ether;
            return originalDiscount.mul(discountDurationInSeconds.sub(diff)).div(discountDurationInSeconds);
        }
    }

}