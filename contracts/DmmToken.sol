pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./libs/AssemblyHelpers.sol";
import "./utils/Blacklistable.sol";
import "./interfaces/IDmmController.sol";
import "./interfaces/IDmmToken.sol";
import "./constants/CommonConstants.sol";
import "./constants/DmmErrorCodes.sol";
import "./utils/ERC20.sol";
import "./libs/DmmTokenLibrary.sol";

contract DmmToken is ERC20, Ownable, IDmmToken, AssemblyHelpers {

    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using DmmTokenLibrary for *;

    /***************************
     * Public Constant Fields
     */

    // bytes32 public constant PERMIT_TYPE_HASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant PERMIT_TYPE_HASH = 0x22fa96956322098f6fd394e06f1b7e0f6930565923f9ad3d20802e9a2eb58fb1;

    // bytes32 public constant TRANSFER_TYPE_HASH = keccak256("Transfer(address owner,address recipient,uint256 nonce,uint256 expiry,uint amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant TRANSFER_TYPE_HASH = 0x25166116e36b48414096856a22ea40032193e38f65136c76738e306be6abd587;

    // bytes32 public constant MINT_TYPE_HASH = keccak256("Mint(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant MINT_TYPE_HASH = 0x82e81310e0eab12a427992778464769ef831d801011489bc90ed3ef82f2cb3d1;

    // bytes32 public constant REDEEM_TYPE_HASH = keccak256("Redeem(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant REDEEM_TYPE_HASH = 0x24e7162538bf7f86bd3180c9ee9f60f06db3bd66eb344ea3b00f69b84af5ddcf;

    /*****************
     * Public Fields
     */

    string public symbol;
    string public name;
    uint8 public decimals;
    uint public minMintAmount;
    uint public minRedeemAmount;

    IDmmController public controller;
    bytes32 public domainSeparator;

    /*****************
     * Private Fields
     */

    Storage private _storage;

    constructor(
        string memory _symbol,
        string memory _name,
        uint8 _decimals,
        uint _minMintAmount,
        uint _minRedeemAmount,
        uint _totalSupply,
        address _controller
    ) public {
        symbol = _symbol;
        name = _name;
        decimals = _decimals;
        minMintAmount = _minMintAmount;
        minRedeemAmount = _minRedeemAmount;
        controller = IDmmController(_controller);

        domainSeparator = keccak256(abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(/* version */ "1")),
                chainId(),
                address(this)
            ));

        _storage = Storage({
            exchangeRate : DmmTokenLibrary.getExchangeRateBaseRate(),
            exchangeRateLastUpdatedTimestamp : block.timestamp
            });

        mintToThisContract(_totalSupply);
    }

    /********************
     * Modifiers
     */

    modifier isNotDisabled {
        require(controller.isMarketEnabled(address(this)), "MARKET_DISABLED");
        _;
    }

    /********************
     * Public Functions
     */

    function() payable external {
        revert("NO_DEFAULT_FUNCTION");
    }

    function pausable() public view returns (address) {
        return address(controller);
    }

    function blacklistable() public view returns (Blacklistable) {
        return controller.blacklistable();
    }

    function activeSupply() public view returns (uint) {
        return totalSupply().sub(balanceOf(address(this)));
    }

    function increaseTotalSupply(uint amount) public onlyOwner whenNotPaused {
        uint oldTotalSupply = _totalSupply;
        mintToThisContract(amount);
        emit TotalSupplyIncreased(oldTotalSupply, _totalSupply);
    }

    function decreaseTotalSupply(uint amount) public onlyOwner whenNotPaused {
        // If there's underflow, throw the specified error
        require(balanceOf(address(this)) >= amount, "TOO_MUCH_ACTIVE_SUPPLY");
        uint oldTotalSupply = _totalSupply;
        burnFromThisContract(amount);
        emit TotalSupplyDecreased(oldTotalSupply, _totalSupply);
    }

    function depositUnderlying(uint underlyingAmount) onlyOwner whenNotPaused public returns (bool) {
        return this._depositUnderlying(_msgSender(), underlyingAmount);
    }

    function withdrawUnderlying(uint underlyingAmount) onlyOwner whenNotPaused public returns (bool) {
        return this._withdrawUnderlying(_msgSender(), underlyingAmount);
    }

    function currentExchangeRate() public view returns (uint) {
        return _storage.getCurrentExchangeRate(controller.getInterestRate(address(this)));
    }

    function exchangeRateLastUpdatedTimestamp() public view returns (uint) {
        return _storage.exchangeRateLastUpdatedTimestamp;
    }

    function nonceOf(address owner) public view returns (uint) {
        return _storage.nonces[owner];
    }

    function mint(
        uint amount
    )
    whenNotPaused
    isNotDisabled
    public returns (uint) {
        blacklistable().checkNotBlacklisted(_msgSender());

        uint currentExchangeRate = this.updateExchangeRateIfNecessaryAndGet(_storage);
        uint underlyingAmount = amount.amountToUnderlying(currentExchangeRate);
        this._mintDmm(_msgSender(), _msgSender(), amount, underlyingAmount);
        require(amount >= minMintAmount, "INSUFFICIENT_MINT_AMOUNT");
        return underlyingAmount;
    }

    function mintFrom(
        uint amount,
        address sender,
        address recipient
    )
    whenNotPaused
    isNotDisabled
    public returns (uint) {
        blacklistable().checkNotBlacklisted(_msgSender());
        blacklistable().checkNotBlacklisted(sender);
        blacklistable().checkNotBlacklisted(recipient);

        uint currentExchangeRate = this.updateExchangeRateIfNecessaryAndGet(_storage);
        uint underlyingAmount = amount.amountToUnderlying(currentExchangeRate);
        this._mintDmm(sender, recipient, amount, underlyingAmount);
        require(amount >= minMintAmount, "INSUFFICIENT_MINT_AMOUNT");
        return underlyingAmount;
    }

    function mintFromGaslessRequest(
        address owner,
        address recipient,
        uint nonce,
        uint expiry,
        uint amount,
        uint feeAmount,
        address feeRecipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    whenNotPaused
    isNotDisabled
    public returns (uint) {
        blacklistable().checkNotBlacklisted(_msgSender());
        blacklistable().checkNotBlacklisted(owner);
        blacklistable().checkNotBlacklisted(recipient);
        if (feeRecipient != address(0x0)) {
            blacklistable().checkNotBlacklisted(feeRecipient);
        }

        // To avoid stack too deep issues, splitting the call into 2 parts is essential.
        _storage.validateOffChainMint(domainSeparator, MINT_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient, v, r, s);

        uint amountLessFee = amount.sub(feeAmount, "FEE_TOO_LARGE");
        require(amountLessFee >= minMintAmount, "INSUFFICIENT_MINT_AMOUNT");

        uint currentExchangeRate = this.updateExchangeRateIfNecessaryAndGet(_storage);
        uint underlyingAmount = amountLessFee.amountToUnderlying(currentExchangeRate);
        this._mintDmm(owner, recipient, amountLessFee, underlyingAmount);

        if (feeAmount > 0) {
            // Mint to the fee recipient
            uint underlyingFeeAmount = feeAmount.amountToUnderlying(currentExchangeRate);
            this._mintDmm(owner, feeRecipient, feeAmount, underlyingFeeAmount);
        }

        return amountLessFee;
    }

    function redeem(
        uint amount
    )
    whenNotPaused
    public returns (uint) {
        blacklistable().checkNotBlacklisted(_msgSender());

        uint currentExchangeRate = this.updateExchangeRateIfNecessaryAndGet(_storage);
        uint underlyingAmount = amount.amountToUnderlying(currentExchangeRate);
        this._redeemDmm(_msgSender(), _msgSender(), amount, underlyingAmount);
        require(amount >= minRedeemAmount, "INSUFFICIENT_REDEEM_AMOUNT");
        return underlyingAmount;
    }

    function redeemFrom(
        uint amount,
        address sender,
        address recipient
    )
    whenNotPaused
    public returns (uint) {
        blacklistable().checkNotBlacklisted(_msgSender());
        blacklistable().checkNotBlacklisted(sender);
        blacklistable().checkNotBlacklisted(recipient);

        uint currentExchangeRate = this.updateExchangeRateIfNecessaryAndGet(_storage);
        uint underlyingAmount = amount.amountToUnderlying(currentExchangeRate);
        this._redeemDmm(sender, recipient, amount, underlyingAmount);
        require(amount >= minRedeemAmount, "INSUFFICIENT_REDEEM_AMOUNT");
        return underlyingAmount;
    }

    function redeemFromGaslessRequest(
        address owner,
        address recipient,
        uint nonce,
        uint expiry,
        uint amount,
        uint feeAmount,
        address feeRecipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    whenNotPaused
    public returns (uint) {
        blacklistable().checkNotBlacklisted(_msgSender());
        blacklistable().checkNotBlacklisted(owner);
        blacklistable().checkNotBlacklisted(recipient);
        if (feeRecipient != address(0x0)) {
            blacklistable().checkNotBlacklisted(feeRecipient);
        }

        // To avoid stack too deep issues, splitting the call into 2 parts is essential.
        _storage.validateOffChainRedeem(domainSeparator, REDEEM_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient, v, r, s);

        uint amountLessFee = amount.sub(feeAmount, "FEE_TOO_LARGE");
        require(amountLessFee >= minRedeemAmount, "INSUFFICIENT_REDEEM_AMOUNT");

        uint currentExchangeRate = this.updateExchangeRateIfNecessaryAndGet(_storage);
        uint underlyingAmount = amountLessFee.amountToUnderlying(currentExchangeRate);
        this._redeemDmm(owner, recipient, amountLessFee, underlyingAmount);
        doFeeTransferForDmmIfNecessary(owner, feeRecipient, feeAmount);

        return underlyingAmount;
    }

    function permit(
        address owner,
        address spender,
        uint nonce,
        uint expiry,
        bool allowed,
        uint feeAmount,
        address feeRecipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    whenNotPaused
    public {
        blacklistable().checkNotBlacklisted(_msgSender());
        blacklistable().checkNotBlacklisted(owner);
        blacklistable().checkNotBlacklisted(spender);
        if (feeRecipient != address(0x0)) {
            blacklistable().checkNotBlacklisted(feeRecipient);
        }

        _storage.validateOffChainPermit(domainSeparator, PERMIT_TYPE_HASH, owner, spender, nonce, expiry, allowed, feeAmount, feeRecipient, v, r, s);

        uint wad = allowed ? uint(- 1) : 0;
        _approve(owner, spender, wad);

        require(balanceOf(owner) >= feeAmount, "INSUFFICIENT_BALANCE_FOR_FEE");
        doFeeTransferForDmmIfNecessary(owner, feeRecipient, feeAmount);
    }

    function transferFromGaslessRequest(
        address owner,
        address recipient,
        uint nonce,
        uint expiry,
        uint amount,
        uint feeAmount,
        address feeRecipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    whenNotPaused
    public {
        blacklistable().checkNotBlacklisted(_msgSender());
        blacklistable().checkNotBlacklisted(owner);
        blacklistable().checkNotBlacklisted(recipient);
        if (feeRecipient != address(0x0)) {
            blacklistable().checkNotBlacklisted(feeRecipient);
        }

        _storage.validateOffChainTransfer(domainSeparator, TRANSFER_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient, v, r, s);

        uint amountLessFee = amount.sub(feeAmount, "FEE_TOO_LARGE");
        _transfer(owner, recipient, amountLessFee);
        doFeeTransferForDmmIfNecessary(owner, feeRecipient, feeAmount);
    }

    /************************************
     * Private & Internal Functions
     */

    function doFeeTransferForDmmIfNecessary(address owner, address feeRecipient, uint feeAmount) private {
        if (feeAmount > 0) {
            _transfer(owner, feeRecipient, feeAmount);
            emit FeeTransfer(owner, feeRecipient, feeAmount);
        }
    }

}
