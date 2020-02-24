pragma solidity ^0.5.0;

import "../../node_modules/@openzeppelin/contracts/lifecycle/Pausable.sol";
import "../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../node_modules/@openzeppelin/contracts/utils/Address.sol";

import "../constants/CommonConstants.sol";
import "../impl/DmmBlacklistable.sol";
import "../interfaces/ICollateralValuator.sol";
import "../interfaces/IDmmController.sol";
import "../interfaces/IDmmToken.sol";
import "../interfaces/InterestRateInterface.sol";
import "../interfaces/IUnderlyingTokenValuator.sol";
import "../interfaces/IDmmTokenFactory.sol";
import "../utils/Blacklistable.sol";
import "../interfaces/IPausable.sol";
import "../interfaces/IOffChainAssetValuator.sol";

contract DmmController is IPausable, Pausable, CommonConstants, IDmmController, Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    /********************************
     * Events
     */

    event InterestRateInterfaceChanged(address previousInterestRateInterface, address newInterestRateInterface);
    event CollateralValuatorChanged(address previousCollateralValuator, address newCollateralValuator);
    event UnderlyingTokenValuatorChanged(address previousUnderlyingTokenValuator, address newUnderlyingTokenValuator);

    event MarketAdded(uint indexed dmmTokenId, address indexed dmmToken, address indexed underlyingToken);

    event DisableMarket(uint indexed dmmTokenId);
    event EnableMarket(uint indexed dmmTokenId);

    event MinCollateralizationChanged(uint previousMinCollateralization, uint newMinCollateralization);
    event MinReserveRatioChanged(uint previousMinReserveRatio, uint newMinReserveRatio);

    /********************************
     * Controller Fields
     */

    DmmBlacklistable public dmmBlacklistable;
    InterestRateInterface public interestRateInterface;
    IOffChainAssetValuator public offChainAssetValuator;
    ICollateralValuator public collateralValuator;
    IUnderlyingTokenValuator public underlyingTokenValuator;
    IDmmTokenFactory public dmmTokenFactory;
    IDmmTokenFactory public dmmEtherFactory;
    uint public minCollateralization;
    uint public minReserveRatio;
    address public wethToken;

    /********************************
     * DMM Account Management
     */

    mapping(uint => address) public dmmTokenIdToDmmTokenAddressMap;
    mapping(address => uint) public dmmTokenAddressToDmmTokenIdMap;

    mapping(address => uint) public underlyingTokenAddressToDmmTokenIdMap;
    mapping(uint => address) public dmmTokenIdToUnderlyingTokenAddressMap;

    mapping(uint => bool) public dmmTokenIdToIsDisabledMap;
    uint[] public dmmTokenIds;

    /********************************
     * Constants
     */

    uint public constant COLLATERALIZATION_BASE_RATE = 1e18;
    uint public constant MIN_RESERVE_RATIO_BASE_RATE = 1e18;

    constructor(
        address _interestRateInterface,
        address _collateralValuator,
        address _offChainAssetValuator,
        address _underlyingTokenValuator,
        address _dmmEtherFactory,
        address _dmmTokenFactory,
        address _dmmBlacklistable,
        uint256 _minCollateralization,
        uint256 _minReserveRatio,
        address _wethToken
    ) public {
        interestRateInterface = InterestRateInterface(_interestRateInterface);
        collateralValuator = ICollateralValuator(_collateralValuator);
        offChainAssetValuator = IOffChainAssetValuator(_offChainAssetValuator);
        underlyingTokenValuator = IUnderlyingTokenValuator(_underlyingTokenValuator);
        dmmTokenFactory = IDmmTokenFactory(_dmmTokenFactory);
        dmmEtherFactory = IDmmTokenFactory(_dmmEtherFactory);
        dmmBlacklistable = DmmBlacklistable(_dmmBlacklistable);
        minCollateralization = _minCollateralization;
        minReserveRatio = _minReserveRatio;
        wethToken = _wethToken;
    }

    /*****************
     * Modifiers
     */

    modifier whenNotPaused() {
        require(!paused(), "ECOSYSTEM_PAUSED");
        _;
    }

    modifier whenPaused() {
        require(paused(), "ECOSYSTEM_NOT_PAUSED");
        _;
    }

    modifier checkTokenExists(uint dmmTokenId) {
        require(dmmTokenIdToDmmTokenAddressMap[dmmTokenId] != address(0x0), "TOKEN_DOES_NOT_EXIST");
        _;
    }

    /**********************
     * Public Functions
     */

    function transferOwnership(address newOwner) public onlyOwner {
        address oldOwner = owner();
        super.transferOwnership(newOwner);
        _removePauser(oldOwner);
        _addPauser(newOwner);
    }

    function blacklistable() public view returns (Blacklistable) {
        return dmmBlacklistable;
    }

    function addMarket(
        address underlyingToken,
        string memory symbol,
        string memory name,
        uint8 decimals,
        uint minMintAmount,
        uint minRedeemAmount,
        uint totalSupply
    ) public onlyOwner {
        require(underlyingTokenAddressToDmmTokenIdMap[underlyingToken] == 0, "TOKEN_ALREADY_EXISTS");

        IDmmToken dmmToken;
        address controller = address(this);
        if (underlyingToken == wethToken) {
            dmmToken = dmmEtherFactory.deployToken(
                symbol,
                name,
                decimals,
                minMintAmount,
                minRedeemAmount,
                totalSupply,
                controller
            );
        } else {
            dmmToken = dmmTokenFactory.deployToken(
                symbol,
                name,
                decimals,
                minMintAmount,
                minRedeemAmount,
                totalSupply,
                controller
            );
        }

        _addMarket(address(dmmToken), underlyingToken);
    }

    function addMarketFromExistingDmmToken(
        address dmmToken,
        address underlyingToken
    )
    onlyOwner
    public {
        require(underlyingTokenAddressToDmmTokenIdMap[underlyingToken] == 0, "TOKEN_ALREADY_EXISTS");
        require(Ownable(dmmToken).owner() == address(this), "INVALID_DMM_TOKEN_OWNERSHIP");
        require(dmmToken.isContract(), "DMM_TOKEN_IS_NOT_CONTRACT");

        _addMarket(dmmToken, underlyingToken);
    }

    function transferTokensOwnershipToNewController(
        uint[] memory dmmTokenIds,
        address newController
    )
    onlyOwner
    public {
        require(newController.isContract(), "NEW_CONTROLLER_IS_NOT_CONTRACT");
        for(uint i = 0; i < dmmTokenIds.length; i++) {
            address dmmToken = dmmTokenIdToDmmTokenAddressMap[dmmTokenIds[i]];
            Ownable(dmmToken).transferOwnership(newController);
        }
    }

    function enableMarket(uint dmmTokenId) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        require(dmmTokenIdToIsDisabledMap[dmmTokenId], "MARKET_ALREADY_ENABLED");
        dmmTokenIdToIsDisabledMap[dmmTokenId] = false;
        emit EnableMarket(dmmTokenId);
    }

    function disableMarket(uint dmmTokenId) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        require(!dmmTokenIdToIsDisabledMap[dmmTokenId], "MARKET_ALREADY_DISABLED");
        dmmTokenIdToIsDisabledMap[dmmTokenId] = true;
        emit DisableMarket(dmmTokenId);
    }

    function setInterestRateInterface(address newInterestRateInterface) public whenNotPaused onlyOwner {
        address oldInterestRateInterface = address(interestRateInterface);
        interestRateInterface = InterestRateInterface(newInterestRateInterface);
        emit InterestRateInterfaceChanged(oldInterestRateInterface, address(interestRateInterface));
    }

    function setCollateralValuator(address newCollateralValuator) public whenNotPaused onlyOwner {
        address oldCollateralValuator = address(collateralValuator);
        collateralValuator = ICollateralValuator(newCollateralValuator);
        emit CollateralValuatorChanged(oldCollateralValuator, address(collateralValuator));
    }

    function setUnderlyingTokenValuator(address newUnderlyingTokenValuator) public whenNotPaused onlyOwner {
        address oldUnderlyingTokenValuator = address(underlyingTokenValuator);
        underlyingTokenValuator = IUnderlyingTokenValuator(newUnderlyingTokenValuator);
        emit UnderlyingTokenValuatorChanged(oldUnderlyingTokenValuator, address(underlyingTokenValuator));
    }

    function setMinCollateralization(uint newMinCollateralization) public whenNotPaused onlyOwner {
        uint oldMinCollateralization = minCollateralization;
        minCollateralization = newMinCollateralization;
        emit MinCollateralizationChanged(oldMinCollateralization, minCollateralization);
    }

    function setMinReserveRatio(uint newMinReserveRatio) public whenNotPaused onlyOwner {
        uint oldMinReserveRatio = minReserveRatio;
        minReserveRatio = newMinReserveRatio;
        emit MinReserveRatioChanged(oldMinReserveRatio, minReserveRatio);
    }

    function increaseTotalSupply(
        uint dmmTokenId,
        uint amount
    ) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenId]).increaseTotalSupply(amount);
        require(getTotalCollateralization() >= minCollateralization, "INSUFFICIENT_COLLATERAL");
    }

    function decreaseTotalSupply(
        uint dmmTokenId,
        uint amount
    ) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenId]).decreaseTotalSupply(amount);
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
        uint totalOwedAmount = token.activeSupply().mul(token.getCurrentExchangeRate()).div(EXCHANGE_RATE_BASE_RATE);
        uint underlyingBalance = IERC20(dmmTokenIdToUnderlyingTokenAddressMap[dmmTokenId]).balanceOf(address(token));

        // IE if we owe 100 and have an underlying balance of 10 --> reserve ratio is 0.1
        uint actualReserveRatio = underlyingBalance.mul(MIN_RESERVE_RATIO_BASE_RATE).div(totalOwedAmount);

        require(actualReserveRatio >= minReserveRatio, "INSUFFICIENT_LEFTOVER_RESERVES");

        emit AdminWithdraw(_msgSender(), underlyingAmount);
    }

    function adminDepositFunds(
        uint dmmTokenId,
        uint256 underlyingAmount
    ) public checkTokenExists(dmmTokenId) whenNotPaused onlyOwner {
        // Attempt to pull from the sender into this contract, then have the DMM token pull from here.
        IERC20 underlyingToken = IERC20(dmmTokenIdToUnderlyingTokenAddressMap[dmmTokenId]);
        underlyingToken.safeTransferFrom(_msgSender(), address(this), underlyingAmount);

        address dmmTokenAddress = dmmTokenIdToDmmTokenAddressMap[dmmTokenId];
        underlyingToken.approve(dmmTokenAddress, underlyingAmount);
        IDmmToken(dmmTokenAddress).depositUnderlying(underlyingAmount);
        emit AdminDeposit(_msgSender(), underlyingAmount);
    }

    function getTotalCollateralization() public view returns (uint) {
        uint totalLiabilities = 0;
        for (uint i = 0; i < dmmTokenIds.length; i++) {
            // IDs start at 1
            IDmmToken token = IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenIds[i]]);
            uint underlyingValue = getSupplyValue(token, IERC20(address(token)).totalSupply());
            totalLiabilities = totalLiabilities.add(underlyingValue);
        }
        // TODO - need to factor in
        // TODO - 1) how much in underlying is in the contracts
        // TODO - 2) off-chain collateral via the interface
        if (totalLiabilities == 0) {
            return 0;
        }
        uint collateralValue = collateralValuator.getCollateralValue();
        return collateralValue.mul(COLLATERALIZATION_BASE_RATE).div(totalLiabilities);
    }

    function getCollateralization(uint totalLiabilities) private view returns (uint) {
        if (totalLiabilities == 0) {
            return 0;
        }
        uint collateralValue = collateralValuator.getCollateralValue();
        return collateralValue.mul(COLLATERALIZATION_BASE_RATE).div(totalLiabilities);
    }

    function getActiveCollateralization() public view returns (uint) {
        uint totalLiabilities = 0;
        for (uint i = 0; i < dmmTokenIds.length; i++) {
            // IDs start at 1
            IDmmToken token = IDmmToken(dmmTokenIdToDmmTokenAddressMap[dmmTokenIds[i]]);
            uint underlyingValue = getSupplyValue(token, token.activeSupply());
            totalLiabilities = totalLiabilities.add(underlyingValue);
        }
        if (totalLiabilities == 0) {
            return 0;
        }
        uint collateralValue = collateralValuator.getCollateralValue();
        return collateralValue.mul(COLLATERALIZATION_BASE_RATE).div(totalLiabilities);
    }

    function getInterestRateByUnderlyingTokenAddress(address underlyingToken) public view returns (uint) {
        uint dmmTokenId = underlyingTokenAddressToDmmTokenIdMap[underlyingToken];
        return getInterestRateByDmmTokenId(dmmTokenId);
    }

    function getInterestRateByDmmTokenId(uint dmmTokenId) checkTokenExists(dmmTokenId) public view returns (uint) {
        address dmmToken = dmmTokenIdToDmmTokenAddressMap[dmmTokenId];
        uint totalSupply = IERC20(dmmToken).totalSupply();
        uint activeSupply = IDmmToken(dmmToken).activeSupply();
        return interestRateInterface.getInterestRate(dmmTokenId, totalSupply, activeSupply);
    }

    function getInterestRateByDmmTokenAddress(address dmmToken) public view returns (uint) {
        uint dmmTokenId = dmmTokenAddressToDmmTokenIdMap[dmmToken];
        require(dmmTokenId != 0, "TOKEN_DOES_NOT_EXIST");

        uint totalSupply = IERC20(dmmToken).totalSupply();
        uint activeSupply = IDmmToken(dmmToken).activeSupply();
        return interestRateInterface.getInterestRate(dmmTokenId, totalSupply, activeSupply);
    }

    function getExchangeRateByUnderlying(address underlyingToken) public view returns (uint) {
        address dmmToken = getDmmTokenForUnderlying(underlyingToken);
        return IDmmToken(dmmToken).getCurrentExchangeRate();
    }

    function getExchangeRate(address dmmToken) public view returns (uint) {
        uint dmmTokenId = dmmTokenAddressToDmmTokenIdMap[dmmToken];
        require(dmmTokenId != 0, "TOKEN_DOES_NOT_EXIST");

        return IDmmToken(dmmToken).getCurrentExchangeRate();
    }

    function getDmmTokenForUnderlying(address underlyingToken) public view returns (address) {
        uint dmmTokenId = underlyingTokenAddressToDmmTokenIdMap[underlyingToken];
        require(dmmTokenId != 0, "TOKEN_DOES_NOT_EXIST");

        return dmmTokenIdToDmmTokenAddressMap[dmmTokenId];
    }

    function getUnderlyingTokenForDmm(address dmmToken) public view returns (address) {
        uint dmmTokenId = dmmTokenAddressToDmmTokenIdMap[dmmToken];
        require(dmmTokenId != 0, "TOKEN_DOES_NOT_EXIST");

        return dmmTokenIdToUnderlyingTokenAddressMap[dmmTokenId];
    }

    function isMarketEnabledByDmmTokenId(uint dmmTokenId) checkTokenExists(dmmTokenId) public view returns (bool) {
        return !dmmTokenIdToIsDisabledMap[dmmTokenId];
    }

    function isMarketEnabledByDmmTokenAddress(address dmmToken) public view returns (bool) {
        uint dmmTokenId = dmmTokenAddressToDmmTokenIdMap[dmmToken];
        require(dmmTokenId != 0, "TOKEN_DOES_NOT_EXIST");

        return !dmmTokenIdToIsDisabledMap[dmmTokenId];
    }

    function getTokenIdFromDmmTokenAddress(address dmmToken) public view returns (uint) {
        uint dmmTokenId = dmmTokenAddressToDmmTokenIdMap[dmmToken];
        require(dmmTokenId != 0, "TOKEN_DOES_NOT_EXIST");

        return dmmTokenId;
    }

    function getDmmTokenIds() public view returns (uint[] memory) {
        return dmmTokenIds;
    }

    /**********************
     * Private Functions
     */

    function _addMarket(address dmmToken, address underlyingToken) private {
        // Start the IDs at 1. Zero is reserved for the empty case when it doesn't exist.
        uint dmmTokenId = dmmTokenIds.length + 1;
        address controller = address(this);

        // Update the maps
        dmmTokenIdToDmmTokenAddressMap[dmmTokenId] = dmmToken;
        dmmTokenAddressToDmmTokenIdMap[dmmToken] = dmmTokenId;
        underlyingTokenAddressToDmmTokenIdMap[underlyingToken] = dmmTokenId;
        dmmTokenIdToUnderlyingTokenAddressMap[dmmTokenId] = underlyingToken;

        // Misc. Structures
        dmmTokenIdToIsDisabledMap[dmmTokenId] = false;
        dmmTokenIds.push(dmmTokenId);

        emit MarketAdded(dmmTokenId, dmmToken, underlyingToken);
    }

    function getSupplyValue(IDmmToken token, uint supply) private view returns (uint) {
        uint underlyingTokenAmount = supply.mul(token.getCurrentExchangeRate()).div(EXCHANGE_RATE_BASE_RATE);
        // The amount returned must use 18 decimal places, regardless of the # of decimals this token has.
        uint standardizedUnderlyingTokenAmount;
        if (token.decimals() == 18) {
            standardizedUnderlyingTokenAmount = underlyingTokenAmount;
        } else if (token.decimals() < 18) {
            standardizedUnderlyingTokenAmount = underlyingTokenAmount.mul((10 ** (18 - uint256(token.decimals()))));
        } else /* decimals > 18 */ {
            standardizedUnderlyingTokenAmount = underlyingTokenAmount.div((10 ** (uint256(token.decimals()) - 18)));
        }
        address underlyingToken = getUnderlyingTokenForDmm(address(token));
        return underlyingTokenValuator.getTokenValue(underlyingToken, standardizedUnderlyingTokenAmount);
    }

}
