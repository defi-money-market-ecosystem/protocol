pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/ICollateralValuator.sol";

import "chainlink/v0.5/contracts/ChainlinkClient.sol";

contract ChainlinkCollateralValuator is ICollateralValuator, ChainlinkClient, Ownable {

    using SafeERC20 for IERC20;

    uint private _oraclePayment;
    bytes32 private _collateralValueJobId;
    uint private _collateralValue;
    uint private _lastUpdatedTimestamp;
    uint private _lastUpdatedBlockNumber;

    constructor(
        uint oraclePayment,
        bytes32 collateralValueJobId
    ) public {
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

    function deposit(address token, uint amount) public onlyOwner {
        IERC20(token).transferFrom(_msgSender(), address(this), amount);
    }

    function withdraw(address token, address recipient, uint amount) public onlyOwner {
        IERC20(token).safeTransfer(recipient, amount);
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

    function getCollateralValue(
        address oracle
    ) public onlyOwner {
        Chainlink.Request memory req = buildChainlinkRequest(
            _collateralValueJobId,
            address(this),
            this.fulfillGetCollateralValue.selector
        );
        sendChainlinkRequestTo(oracle, req, _oraclePayment);
    }

    function fulfillGetCollateralValue(
        bytes32 _requestId,
        uint collateralValue
    ) public recordChainlinkFulfillment(_requestId) {
        _collateralValue = collateralValue;
        _lastUpdatedTimestamp = block.timestamp;
        _lastUpdatedBlockNumber = block.number;
    }

}