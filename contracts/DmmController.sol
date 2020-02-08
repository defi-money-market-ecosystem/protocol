pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

import "./libs/Blacklistable.sol";
import "./libs/DmmErrorCodes.sol";
import "./libs/ICollateralValuator.sol";
import "./libs/IDmmController.sol";
import "./libs/IDmmToken.sol";
import "./libs/InterestRateInterface.sol";
import "./libs/IUnderlyingTokenValuator.sol";
import "./DmmToken.sol";
import "./DmmBlacklistable.sol";

contract DmmController is IDmmController, DmmErrorCodes, Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /********************************
     * Events
     */

    event InterestRateInterfaceChanged(address newInterestRateInterface);
    event CollateralValuatorChanged(address newCollateralValuator);
    event UnderlyingTokenValuatorChanged(address newUnderlyingTokenValuator);

    /********************************
     * Controller Fields
     */

    DmmBlacklistable public dmmBlacklistable;
    InterestRateInterface public interestRateInterface;
    ICollateralValuator public collateralValuator;
    IUnderlyingTokenValuator public underlyingTokenValuator;
    uint public minReserveRatio;
    uint public minCollateralization;
    bool public isEcosystemPaused;

    /********************************
     * DMM Account Management
     */

    mapping(uint => address) public dmmTokenIdToDmmTokenAddressMap;
    mapping(address => uint) public dmmTokenAddressToDmmTokenIdMap;

    mapping(address => uint) public underlyingTokenAddressToDmmTokenIdMap;
    mapping(uint => address) public dmmTokenIdToUnderlyingTokenAddressMap;

    mapping(uint => bool) public dmmTokenIdToIsDisabledMap;
    uint[] dmmTokenIds;

    /********************************
     * Constants
     */

    uint public constant COLLATERALIZATION_BASE_RATE = 1e18;
    uint public constant MIN_RESERVE_RATIO_BASE_RATE = 1e18;

    constructor(
        address _interestRateInterface,
        address _collateralValuator,
        address _underlyingTokenValuator,
        uint256 _minReserveRatio,
        uint256 _minCollateralization,
        address _dmmBlacklistable
    ) public {
        interestRateInterface = InterestRateInterface(_interestRateInterface);
        collateralValuator = ICollateralValuator(_collateralValuator);
        underlyingTokenValuator = IUnderlyingTokenValuator(_underlyingTokenValuator);
        dmmBlacklistable = DmmBlacklistable(_dmmBlacklistable);
        minReserveRatio = _minReserveRatio;
        minCollateralization = _minCollateralization;

        isEcosystemPaused = false;
    }

    /*****************
     * Modifiers
     */

    modifier whenNotPaused {
        require(!isEcosystemPaused, ECOSYSTEM_PAUSED);
        _;
    }

    modifier checkTokenExists(uint dmmTokenId) {
        require(dmmTokenIdToDmmTokenAddressMap[dmmTokenId] != address(0x0), TOKEN_DOES_NOT_EXIST);
        _;
    }

    /**********************
     * Public Functions
     */

    function blacklistable() public view returns (address) {
        return address(dmmBlacklistable);
    }

    function addMarket(
        address underlyingToken,
        string memory symbol,
        string memory name,
        uint8 decimals,
        uint minMintAmount,
        uint minRedeemAmount,
        uint totalSupply
    ) public {
        // Start the IDs at 1. Zero is reserved for the empty case when it doesn't exist.
        uint dmmTokenId = dmmTokenIds.length + 1;
        DmmToken dmmToken = new DmmToken(
            symbol,
            name,
            decimals,
            minMintAmount,
            minRedeemAmount,
            totalSupply,
        /* controller */ address(this)
        );
        address dmmTokenAddress = address(dmmToken);

        // Update the maps
        dmmTokenIdToDmmTokenAddressMap[dmmTokenId] = dmmTokenAddress;
        dmmTokenAddressToDmmTokenIdMap[dmmTokenAddress] = dmmTokenId;
        underlyingTokenAddressToDmmTokenIdMap[underlyingToken] = dmmTokenId;
        dmmTokenIdToUnderlyingTokenAddressMap[dmmTokenId] = underlyingToken;

        // Misc. Structures
        dmmTokenIdToIsDisabledMap[dmmTokenId] = false;
        dmmTokenIds.push(dmmTokenId);
    }

    function enableMarket(uint dmmTokenId) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        require(dmmTokenIdToIsDisabledMap[dmmTokenId], MARKET_ALREADY_ENABLED);
        dmmTokenIdToIsDisabledMap[dmmTokenId] = false;
    }

    function disableMarket(uint dmmTokenId) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        require(!dmmTokenIdToIsDisabledMap[dmmTokenId], MARKET_ALREADY_DISABLED);
        dmmTokenIdToIsDisabledMap[dmmTokenId] = true;
    }

    function resumeEcosystem() public onlyOwner {
        require(isEcosystemPaused, ECOSYSTEM_MUST_BE_PAUSED);
        isEcosystemPaused = false;
    }

    function pauseEcosystem() public onlyOwner {
        require(!isEcosystemPaused, ECOSYSTEM_ALREADY_PAUSED);
        isEcosystemPaused = true;
    }

    function setInterestRateInterface(address newInterestRateInterface) public whenNotPaused onlyOwner {
        interestRateInterface = InterestRateInterface(newInterestRateInterface);
    }

    function setCollateralValuator(address newCollateralValuator) public whenNotPaused onlyOwner {
        collateralValuator = ICollateralValuator(newCollateralValuator);
    }

    function setUnderlyingTokenValuator(address newUnderlyingTokenValuator) public whenNotPaused onlyOwner {
        underlyingTokenValuator = IUnderlyingTokenValuator(newUnderlyingTokenValuator);
    }

    function setMinReserveRatio(uint newMinReserveRatio) public whenNotPaused onlyOwner {
        minReserveRatio = newMinReserveRatio;
    }

    function increaseMaxSupply(
        uint dmmTokenId,
        uint amount
    ) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenId]).increaseTotalSupply(amount);
        require(getTotalCollateralization() >= minCollateralization, INSUFFICIENT_COLLATERAL);
    }

    function decreaseMaxSupply(
        uint dmmTokenId,
        uint amount
    ) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenId]).increaseTotalSupply(amount);
    }

    function adminWithdrawFunds(
        uint dmmTokenId,
        uint256 underlyingAmount
    ) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        // Attempt to pull from the DMM contract into this contract, then send from this contract to sender.
        IDmmToken token = IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenId]);
        token.withdrawUnderlying(underlyingAmount);
        IERC20 underlyingToken = IERC20(dmmTokenIdToUnderlyingTokenAddressMap[dmmTokenId]);
        underlyingToken.safeTransfer(_msgSender(), underlyingAmount);

        // This is the amount owed by the system in terms of underlying
        uint totalOwedAmount = token.activeSupply().mul(token.exchangeRate()).div(token.EXCHANGE_RATE_BASE_RATE());
        uint underlyingBalance = IERC20(dmmTokenIdToUnderlyingTokenAddressMap[dmmTokenId]).balanceOf(address(token));

        // IE if we owe 100 and have an underlying balance of 10 --> reserve ratio is 0.1
        uint actualReserveRatio = underlyingBalance.mul(MIN_RESERVE_RATIO_BASE_RATE).div(totalOwedAmount);

        require(actualReserveRatio >= minReserveRatio, INSUFFICIENT_LEFTOVER_RESERVES);
    }

    function adminDepositFunds(
        uint dmmTokenId,
        uint256 underlyingAmount
    ) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        // Attempt to pull from the sender into this contract, then have the DMM token pull from here.
        IERC20 underlyingToken = IERC20(dmmTokenIdToUnderlyingTokenAddressMap[dmmTokenId]);
        underlyingToken.safeTransferFrom(_msgSender(), address(this), underlyingAmount);
        IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenId]).depositUnderlying(underlyingAmount);
    }

    function getTotalCollateralization() public view returns (uint) {
        uint totalLoanValue = 0;
        for (uint i = 0; i < dmmTokenIds.length; i++) {
            // IDs start at 1
            IDmmToken token = IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenIds[i + 1]]);
            uint underlyingValue = getSupplyValue(token, IERC20(address(token)).totalSupply());
            totalLoanValue = totalLoanValue.add(underlyingValue);
        }
        uint collateralValue = collateralValuator.getCollateralValue();
        return collateralValue.mul(COLLATERALIZATION_BASE_RATE).div(totalLoanValue);
    }

    function getActiveCollateralization() public view returns (uint) {
        uint totalLoanValue = 0;
        for (uint i = 0; i < dmmTokenIds.length; i++) {
            // IDs start at 1
            IDmmToken token = IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenIds[i + 1]]);
            uint underlyingValue = getSupplyValue(token, token.activeSupply());
            totalLoanValue = totalLoanValue.add(underlyingValue);
        }
        uint collateralValue = collateralValuator.getCollateralValue();
        return collateralValue.mul(COLLATERALIZATION_BASE_RATE).div(totalLoanValue);
    }

    function getInterestRateForUnderlying(address underlyingToken) public view returns (uint) {
        uint dmmTokenId = underlyingTokenAddressToDmmTokenIdMap[underlyingToken];
        require(dmmTokenId != 0, TOKEN_DOES_NOT_EXIST);

        return getInterestRate(dmmTokenId);
    }

    function getInterestRate(uint dmmTokenId) checkTokenExists(dmmTokenId) public view returns (uint) {
        address dmmToken = dmmTokenIdToDmmTokenAddressMap[dmmTokenId];
        uint totalSupply = IERC20(dmmToken).totalSupply();
        uint activeSupply = IDmmToken(dmmToken).activeSupply();
        return interestRateInterface.getInterestRate(dmmTokenId, totalSupply, activeSupply);
    }

    function getExchangeRateForUnderlying(address underlyingToken) public view returns (uint) {
        address dmmToken = getDmmTokenForUnderlying(underlyingToken);
        return IDmmToken(dmmToken).exchangeRate();
    }

    function getExchangeRate(address dmmToken) public view returns (uint) {
        return IDmmToken(dmmToken).exchangeRate();
    }

    function getDmmTokenForUnderlying(address underlyingToken) public view returns (address) {
        uint dmmTokenId = underlyingTokenAddressToDmmTokenIdMap[underlyingToken];
        require(dmmTokenId != 0, TOKEN_DOES_NOT_EXIST);

        return dmmTokenIdToDmmTokenAddressMap[dmmTokenId];
    }

    function getUnderlyingTokenForDmm(address dmmToken) public view returns (address) {
        uint dmmTokenId = dmmTokenAddressToDmmTokenIdMap[dmmToken];
        require(dmmTokenId != 0, TOKEN_DOES_NOT_EXIST);

        return dmmTokenIdToUnderlyingTokenAddressMap[dmmTokenId];
    }

    function isMarketEnabled(uint dmmTokenId) checkTokenExists(dmmTokenId) public view returns (bool) {
        return !dmmTokenIdToIsDisabledMap[dmmTokenId];
    }

    function isMarketEnabled(address underlyingToken) public view returns (bool) {
        uint dmmTokenId = underlyingTokenAddressToDmmTokenIdMap[underlyingToken];
        require(dmmTokenId != 0, TOKEN_DOES_NOT_EXIST);

        return !dmmTokenIdToIsDisabledMap[dmmTokenId];
    }

    function getTokenIdFromDmmTokenAddress(address dmmTokenAddress) public view returns (uint) {
        uint dmmTokenId = dmmTokenAddressToDmmTokenIdMap[dmmTokenAddress];
        require(dmmTokenId != 0, TOKEN_DOES_NOT_EXIST);

        return dmmTokenId;
    }

    /**********************
     * Private Functions
     */

    function getSupplyValue(IDmmToken token, uint supply) private view returns (uint) {
        uint underlyingTokenAmount = supply.mul(token.exchangeRate()).div(token.EXCHANGE_RATE_BASE_RATE());
        address underlyingToken = getUnderlyingTokenForDmm(address(token));
        return underlyingTokenValuator.getTokenValue(underlyingToken, underlyingTokenAmount);
    }

}
