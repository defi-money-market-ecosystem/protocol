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

interface IOffChainAssetValuatorV2 {

    // *************************
    // ***** Events
    // *************************

    event AssetsValueUpdated(uint newAssetsValue);
    event AssetTypeSet(uint tokenId, string assetType, bool isAdded);

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
    ) external;

    /**
     * @dev Adds an asset type to be supported by the provided principal / affiliate. Use `tokenId` 0 to denote all
     *      asset introducers.
     */
    function addSupportedAssetTypeByTokenId(
        uint tokenId,
        string calldata assetType
    ) external;

    /**
     * @dev Removes an asset type to be supported by the provided principal / affiliate. Use `tokenId` 0 to denote all
     *      asset introducers.
     */
    function removeSupportedAssetTypeByTokenId(
        uint tokenId,
        string calldata assetType
    ) external;

    /**
     * Sets the oracle job ID for getting all collateral for the ecosystem.
     */
    function setCollateralValueJobId(
        bytes32 jobId
    ) external;

    /**
     * Sets the amount of LINK to be paid for the `collateralValueJobId`
     */
    function setOraclePayment(
        uint oraclePayment
    ) external;

    function submitGetOffChainAssetsValueRequest(
        address oracle
    ) external;

    function fulfillGetOffChainAssetsValueRequest(
        bytes32 requestId,
        uint offChainAssetsValue
    ) external;

    // *************************
    // ***** Misc Functions
    // *************************

    /**
     * @return  The amount of LINK to be paid for fulfilling this oracle request.
     */
    function oraclePayment() external view returns (uint);

    /**
     * @return  The timestamp at which the oracle was last pinged
     */
    function lastUpdatedTimestamp() external view returns (uint);

    /**
     * @return  The block number at which the oracle was last pinged
     */
    function lastUpdatedBlockNumber() external view returns (uint);

    /**
     * @return  The off-chain assets job ID for getting all assets. NOTE this will be broken down by asset introducer
     *          (token ID) in the future so this function will be deprecated.
     */
    function offChainAssetsValueJobId() external view returns (bytes32);

    /**
     * @dev Gets the DMM ecosystem's collateral's value from Chainlink's on-chain data feed.
     *
     * @return The value of all of the ecosystem's collateral, as a number with 18 decimals
     */
    function getOffChainAssetsValue() external view returns (uint);

    /**
     * @dev Gets the DMM ecosystem's collateral's value from Chainlink's on-chain data feed.
     *
     * @param   tokenId The ID of the asset introducer whose assets should be valued or use 0 to denote all introducers.
     * @return          The value of the asset introducer's ecosystem collateral, as a number with 18 decimals.
     */
    function getOffChainAssetsValueByTokenId(
        uint tokenId
    ) external view returns (uint);

    /**
     * @param tokenId   The token ID of the asset introducer; 0 to denote all of them
     * @param assetType The asset type for the collateral (lien) held by the DMM DAO
     * @return True if the asset type is supported, or false otherwise
     */
    function isSupportedAssetTypeByAssetIntroducer(
        uint tokenId,
        string calldata assetType
    ) external view returns (bool);

    /**
     * @return  All of the different asset types that can be used by the DMM Ecosystem.
     */
    function getAllAssetTypes() external view returns (string[] memory);

}
