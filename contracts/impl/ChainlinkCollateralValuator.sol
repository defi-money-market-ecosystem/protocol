pragma solidity ^0.5.0;

import "../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/ICollateralValuator.sol";
import "./AtmLike.sol";

import "../../node_modules/chainlink/v0.5/contracts/ChainlinkClient.sol";

contract ChainlinkCollateralValuator is ICollateralValuator, ChainlinkClient, Ownable, AtmLike {

    /// The amount of LINK to be paid per request
    uint private _oraclePayment;

    /// The job ID that's fired on the LINK nodes to fulfill this contract's need for off-chain data
    bytes32 private _collateralValueJobId;

    /// The value of all off-chain collateral, as determined by Chainlink. This number has 18 decimal places of precision.
    uint private _collateralValue;

    /// The timestamp (in Unix seconds) at which this contract's _collateralValue field was last updated.
    uint private _lastUpdatedTimestamp;

    /// The block number at which this contract's _collateralValue field was last updated.
    uint private _lastUpdatedBlockNumber;

    constructor(
        address linkToken,
        uint oraclePayment,
        bytes32 collateralValueJobId
    ) public {
        setChainlinkToken(linkToken);
        _oraclePayment = oraclePayment;
        _collateralValueJobId = collateralValueJobId;
        _collateralValue = 1e18;
        _lastUpdatedTimestamp = block.timestamp;
        _lastUpdatedBlockNumber = block.number;
    }

    function getLastUpdatedTimestamp() public view returns (uint) {
        return _lastUpdatedTimestamp;
    }

    function getLastUpdatedBlockNumber() public view returns (uint) {
        return _lastUpdatedBlockNumber;
    }

    function getCollateralValue() public view returns (uint) {
        return _collateralValue;
    }

    function getCollateralValueJobId() public view returns (bytes32) {
        return _collateralValueJobId;
    }

    function setCollateralValueJobId(bytes32 collateralValueJobId) public onlyOwner {
        _collateralValueJobId = collateralValueJobId;
    }

    function setOraclePayment(uint oraclePayment) public onlyOwner {
        _oraclePayment = oraclePayment;
    }

    function getCollateralValue(
        address oracle
    ) public onlyOwner {
        Chainlink.Request memory request = buildChainlinkRequest(
            _collateralValueJobId,
            address(this),
            this.fulfillGetCollateralValue.selector
        );
        request.add("action", "sumActive");
        sendChainlinkRequestTo(oracle, request, _oraclePayment);
    }

    function fulfillGetCollateralValue(
        bytes32 requestId,
        uint collateralValue
    ) public recordChainlinkFulfillment(requestId) {
        _collateralValue = collateralValue;
        _lastUpdatedTimestamp = block.timestamp;
        _lastUpdatedBlockNumber = block.number;

        emit CollateralValueUpdated(collateralValue);
    }

}