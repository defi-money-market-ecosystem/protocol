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

library DmmControllerHelper {

    function getDmmTokenAddressByDmmTokenId(
        IFarmDmmController controller,
        uint dmmTokenId
    ) external view returns (address) {
        address token = controller.dmmTokenIdToDmmTokenAddressMap(dmmTokenId);
        require(token != address(0x0), "DmmControllerHelper::getDmmTokenAddressByDmmTokenId INVALID_TOKEN_ID");
        return token;
    }

}

interface IFarmDmmController {

    function dmmTokenIdToDmmTokenAddressMap(uint dmmTokenId) external view returns (address);

}