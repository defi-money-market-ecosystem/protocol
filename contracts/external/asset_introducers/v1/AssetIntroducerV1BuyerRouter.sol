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

import "../../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/IERC721.sol";
import "../interfaces/IERC721TokenReceiver.sol";

import "../AssetIntroducerData.sol";

import "./IAssetIntroducerV1.sol";

/// Allows users to access the DMM Foundation's incentive tokens, for use of price matching the cost of an asset
/// introducer NFT. This is denoted by dividing the effective price of each NFT by 2, since the pool pays for half the
/// cost.
contract AssetIntroducerV1BuyerRouter is IERC721TokenReceiver, Ownable {

    // *************************
    // ***** Events
    // *************************

    event IncentiveDmgUsed(uint indexed tokenId, address indexed buyer, uint amount);

    using SafeERC20 for IERC20;
    using SafeMath for uint;

    IAssetIntroducerV1 public assetIntroducerProxy;
    address public dmg;
    address public dmgIncentivesPool;

    constructor(
        address _owner,
        address _assetIntroducerProxy,
        address _dmg,
        address _dmgIncentivesPool
    ) public {
        assetIntroducerProxy = IAssetIntroducerV1(_assetIntroducerProxy);
        dmg = _dmg;
        dmgIncentivesPool = _dmgIncentivesPool;

        _transferOwnership(_owner);
    }

    function withdrawDustTo(
        address __token,
        address __to,
        uint __amount
    )
    external
    onlyOwner {
        _withdrawDustTo(__token, __to, __amount);
    }

    function withdrawAllDustTo(
        address __token,
        address __to
    )
    external
    onlyOwner {
        _withdrawDustTo(__token, __to, uint(- 1));
    }

    function isReady() public view returns (bool) {
        return IERC20(dmg).allowance(dmgIncentivesPool, address(this)) > 0;
    }

    function getAssetIntroducerPriceUsdByTokenId(
        uint __tokenId
    ) external view returns (uint) {
        return assetIntroducerProxy.getAssetIntroducerPriceUsdByTokenId(__tokenId) / 2;
    }

    function getAssetIntroducerPriceDmgByTokenId(
        uint __tokenId
    ) external view returns (uint) {
        return assetIntroducerProxy.getAssetIntroducerPriceDmgByTokenId(__tokenId) / 2;
    }

    function getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(
        string calldata __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType
    )
    external view returns (uint) {
        return assetIntroducerProxy.getAssetIntroducerPriceUsdByCountryCodeAndIntroducerType(__countryCode, __introducerType) / 2;
    }

    function getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(
        string calldata __countryCode,
        AssetIntroducerData.AssetIntroducerType __introducerType
    )
    external view returns (uint) {
        return assetIntroducerProxy.getAssetIntroducerPriceDmgByCountryCodeAndIntroducerType(__countryCode, __introducerType) / 2;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function buyAssetIntroducerSlot(
        uint __tokenId
    ) external returns (bool) {
        require(
            isReady(),
            "AssetIntroducerBuyerRouter::buyAssetIntroducerSlot: NOT_READY"
        );

        uint fullPriceDmg = assetIntroducerProxy.getAssetIntroducerPriceDmgByTokenId(__tokenId);
        uint userPriceDmg = fullPriceDmg / 2;
        address _dmg = dmg;
        IERC20(_dmg).safeTransferFrom(msg.sender, address(this), userPriceDmg);

        require(
            IERC20(_dmg).balanceOf(dmgIncentivesPool) >= fullPriceDmg.sub(userPriceDmg),
            "AssetIntroducerBuyerRouter::buyAssetIntroducerSlot: INSUFFICIENT_INCENTIVES"
        );
        IERC20(_dmg).safeTransferFrom(dmgIncentivesPool, address(this), fullPriceDmg.sub(userPriceDmg));

        IERC20(_dmg).safeApprove(address(assetIntroducerProxy), fullPriceDmg);

        assetIntroducerProxy.buyAssetIntroducerSlot(__tokenId);

        // Forward the NFT to the purchaser
        IERC721(address(assetIntroducerProxy)).safeTransferFrom(address(this), msg.sender, __tokenId);

        emit IncentiveDmgUsed(__tokenId, msg.sender, fullPriceDmg.sub(userPriceDmg));

        return true;
    }

    // *************************
    // ***** Internal Functions
    // *************************

    function _withdrawDustTo(
        address __token,
        address __to,
        uint __amount
    )
    internal {
        if (__amount == uint(- 1)) {
            __amount = IERC20(__token).balanceOf(address(this));
        }
        IERC20(__token).safeTransfer(__to, __amount);
    }

}