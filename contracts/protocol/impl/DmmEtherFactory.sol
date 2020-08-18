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

import "./DmmEther.sol";
import "../interfaces/IDmmTokenFactory.sol";

contract DmmEtherFactory is Context, IDmmTokenFactory, Ownable {

    address public wethToken;

    constructor(address _wethToken) public {
        wethToken = _wethToken;
    }

    function deployToken(
        string memory symbol,
        string memory name,
        uint8 decimals,
        uint minMintAmount,
        uint minRedeemAmount,
        uint totalSupply,
        address controller
    ) public onlyOwner returns (IDmmToken) {
        DmmEther token = new DmmEther(
            wethToken,
            symbol,
            name,
            decimals,
            minMintAmount,
            minRedeemAmount,
            totalSupply,
            controller
        );
        token.transferOwnership(_msgSender());
        return token;
    }

}