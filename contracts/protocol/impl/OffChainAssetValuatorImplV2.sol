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

import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IOffChainAssetValuatorV2.sol";
import "./AtmLike.sol";

import "../../../node_modules/chainlink/v0.5/contracts/ChainlinkClient.sol";
import "../../external/chainlink/UpgradeableChainlinkClient.sol";
import "./data/OffChainAssetValuatorData.sol";

contract OffChainAssetValuatorImplV2 is IOffChainAssetValuatorV2, OffChainAssetValuatorData {

    // *************************
    // ***** Admin Functions
    // *************************

    function initialize(
        address owner,
        address guardian,
        address linkToken,
        uint oraclePayment,
        uint offChainAssetsValue,
        bytes32 offChainAssetsValueJobId
    )
    external
    initializer {
        IOwnableOrGuardian.initialize(owner, guardian);

        setChainlinkToken(linkToken);
        _oraclePayment = oraclePayment;
        _offChainAssetsValueJobId = offChainAssetsValueJobId;
        _offChainAssetsValue = offChainAssetsValue;
        _lastUpdatedTimestamp = block.timestamp;
        _lastUpdatedBlockNumber = block.number;
    }

    function addSupportedAssetTypeByTokenId(
        uint tokenId,
        string calldata assetType
    )
    external
    onlyOwnerOrGuardian {
        bytes32 bytesAssetType = _sanitizeAndConvertAssetTypeToBytes(assetType);

        require(
            !_assetIntroducerToAssetTypeToIsSupportedMap[tokenId][bytesAssetType],
            "OffChainAssetValuatorImplV2::addSupportedAssetTypeByTokenId: ALREADY_SUPPORTED"
        );

        uint numberOfUses = _assetTypeToNumberOfUsesMap[bytesAssetType];
        if (numberOfUses == 0) {
            _allAssetTypes.push(bytesAssetType);
        }

        _assetTypeToNumberOfUsesMap[bytesAssetType] = numberOfUses.add(1);
        _assetIntroducerToAssetTypeToIsSupportedMap[tokenId][bytesAssetType] = true;

        emit AssetTypeSet(tokenId, assetType, true);
    }

    function removeSupportedAssetTypeByTokenId(
        uint tokenId,
        string calldata assetType
    )
    onlyOwnerOrGuardian
    external {
        bytes32 bytesAssetType = _sanitizeAndConvertAssetTypeToBytes(assetType);

        require(
            _assetIntroducerToAssetTypeToIsSupportedMap[tokenId][bytesAssetType],
            "OffChainAssetValuatorImplV2::addSupportedAssetTypeByTokenId: NOT_SUPPORTED"
        );

        uint numberOfUses = _assetTypeToNumberOfUsesMap[bytesAssetType];
        if (numberOfUses == 1) {
            // We no longer support it. Remove it.
            bytes32[] memory allAssetTypes = _allAssetTypes;
            for (uint i = 0; i < allAssetTypes.length; i++) {
                if (allAssetTypes[i] == bytesAssetType) {
                    delete _allAssetTypes[i];
                    break;
                }
            }
        }

        _assetTypeToNumberOfUsesMap[bytesAssetType] = numberOfUses.sub(1);
        _assetIntroducerToAssetTypeToIsSupportedMap[tokenId][bytesAssetType] = false;

        emit AssetTypeSet(tokenId, assetType, false);
    }

    function setCollateralValueJobId(
        bytes32 offChainAssetsValueJobId
    )
    public
    onlyOwnerOrGuardian {
        _offChainAssetsValueJobId = offChainAssetsValueJobId;
    }

    function setOraclePayment(
        uint oraclePayment
    )
    public
    onlyOwnerOrGuardian {
        _oraclePayment = oraclePayment;
    }

    function submitGetOffChainAssetsValueRequest(
        address oracle
    )
    public
    onlyOwnerOrGuardian {
        Chainlink.Request memory request = buildChainlinkRequest(
            _offChainAssetsValueJobId,
            address(this),
            this.fulfillGetOffChainAssetsValueRequest.selector
        );
        request.add("action", "sumActive");
        request.addInt("times", 1 ether);
        sendChainlinkRequestTo(oracle, request, _oraclePayment);
    }

    function fulfillGetOffChainAssetsValueRequest(
        bytes32 requestId,
        uint offChainAssetsValue
    )
    public
    recordChainlinkFulfillment(requestId) {
        _offChainAssetsValue = offChainAssetsValue;
        _lastUpdatedTimestamp = block.timestamp;
        _lastUpdatedBlockNumber = block.number;

        emit AssetsValueUpdated(offChainAssetsValue);
    }

    // *************************
    // ***** Misc Functions
    // *************************

    function oraclePayment() external view returns (uint) {
        return _oraclePayment;
    }

    function lastUpdatedTimestamp() external view returns (uint) {
        return _lastUpdatedTimestamp;
    }

    function lastUpdatedBlockNumber() external view returns (uint) {
        return _lastUpdatedBlockNumber;
    }

    function offChainAssetsValueJobId() external view returns (bytes32) {
        return _offChainAssetsValueJobId;
    }

    function getOffChainAssetsValue() external view returns (uint) {
        return _offChainAssetsValue;
    }

    function getOffChainAssetsValueByTokenId(
        uint tokenId
    ) external view returns (uint) {
        if (tokenId == 0) {
            return _offChainAssetsValue;
        } else {
            revert("OffChainAssetValuatorImplV2::getOffChainAssetsValueByTokenId NOT_IMPLEMENTED");
        }
    }

    function isSupportedAssetTypeByAssetIntroducer(
        uint tokenId,
        string calldata assetType
    ) external view returns (bool) {
        bytes32 bytesAssetType = _sanitizeAndConvertAssetTypeToBytes(assetType);
        return _assetIntroducerToAssetTypeToIsSupportedMap[0][bytesAssetType] || _assetIntroducerToAssetTypeToIsSupportedMap[tokenId][bytesAssetType];
    }

    function getAllAssetTypes() external view returns (string[] memory) {
        bytes32[] memory allAssetTypes = _allAssetTypes;
        string[] memory result = new string[](allAssetTypes.length);
        for (uint i = 0; i < allAssetTypes.length; i++) {
            result[i] = string(abi.encodePacked(allAssetTypes[i]));
        }
        return result;
    }

    // *************************
    // ***** Internal Functions
    // *************************

    function _sanitizeAndConvertAssetTypeToBytes(
        string memory assetType
    ) internal pure returns (bytes32 bytesAssetType) {
        require(
            bytes(assetType).length <= 32,
            "OffChainAssetValuatorImplV2::_sanitizeAndConvertAssetTypeString: INVALID_LENGTH"
        );

        assembly {
            bytesAssetType := mload(add(assetType, 32))
        }
    }

}