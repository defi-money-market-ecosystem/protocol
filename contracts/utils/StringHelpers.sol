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

library StringHelpers {

    function toString(address _value) internal pure returns (string memory) {
        return toString(abi.encodePacked(_value));
    }

    function toString(uint _value) internal pure returns (string memory) {
        return toString(abi.encodePacked(_value));
    }

    function toString(bytes memory value) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + (value.length * 2));
        str[0] = '0';
        str[1] = 'x';
        for (uint i = 0; i < value.length; i++) {
            str[2 + i * 2] = alphabet[uint(uint8(value[i] >> 4))];
            str[3 + i * 2] = alphabet[uint(uint8(value[i] & 0x0f))];
        }
        return string(str);
    }

}
