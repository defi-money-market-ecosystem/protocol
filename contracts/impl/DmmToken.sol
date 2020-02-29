pragma solidity ^0.5.12;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../libs/DmmTokenLibrary.sol";
import "../interfaces/IDmmController.sol";
import "../interfaces/IDmmToken.sol";
import "../utils/ERC20.sol";
import "../utils/Blacklistable.sol";

contract DmmToken is ERC20, IDmmToken, CommonConstants {

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

    DmmTokenLibrary.Storage private _storage;

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

        uint256 chainId;
        assembly {chainId := chainid()}

        domainSeparator = keccak256(abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(/* version */ "1")),
                chainId,
                address(this)
            ));

        _storage = DmmTokenLibrary.Storage({
            exchangeRate : EXCHANGE_RATE_BASE_RATE,
            exchangeRateLastUpdatedTimestamp : block.timestamp,
            exchangeRateLastUpdatedBlockNumber : block.number
            });

        mintToThisContract(_totalSupply);
    }

    /********************
     * Modifiers
     */

    modifier isNotDisabled {
        require(controller.isMarketEnabledByDmmTokenAddress(address(this)), "MARKET_DISABLED");
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

    function getCurrentExchangeRate() public view returns (uint) {
        return _storage.getCurrentExchangeRate(controller.getInterestRateByDmmTokenAddress(address(this)));
    }

    function exchangeRateLastUpdatedTimestamp() public view returns (uint) {
        return _storage.exchangeRateLastUpdatedTimestamp;
    }

    function exchangeRateLastUpdatedBlockNumber() public view returns (uint) {
        return _storage.exchangeRateLastUpdatedBlockNumber;
    }

    function nonceOf(address owner) public view returns (uint) {
        return _storage.nonces[owner];
    }

    function mint(
        uint underlyingAmount
    )
    whenNotPaused
    nonReentrant
    isNotDisabled
    public returns (uint) {
        return _mint(_msgSender(), _msgSender(), underlyingAmount);
    }

    function transferUnderlyingIn(address owner, uint underlyingAmount) internal {
        address underlyingToken = controller.getUnderlyingTokenForDmm(address(this));
        IERC20(underlyingToken).safeTransferFrom(owner, address(this), underlyingAmount);
    }

    function transferUnderlyingOut(address recipient, uint underlyingAmount) internal {
        address underlyingToken = controller.getUnderlyingTokenForDmm(address(this));
        IERC20(underlyingToken).transfer(recipient, underlyingAmount);
    }

    function mintFromGaslessRequest(
        address owner,
        address recipient,
        uint nonce,
        uint expiry,
        uint underlyingAmount,
        uint feeAmount,
        address feeRecipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    whenNotPaused
    nonReentrant
    isNotDisabled
    public returns (uint) {
        return _mintFromGaslessRequest(
            owner,
            recipient,
            nonce,
            expiry,
            underlyingAmount,
            feeAmount,
            feeRecipient,
            v,
            r,
            s
        );
    }

    function redeem(
        uint amount
    )
    whenNotPaused
    nonReentrant
    public returns (uint) {
        return _redeem(_msgSender(), _msgSender(), amount, /* shouldUseAllowance */ false);
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
    nonReentrant
    public returns (uint) {
        return _redeemFromGaslessRequest(
            owner,
            recipient,
            nonce,
            expiry,
            amount,
            feeAmount,
            feeRecipient,
            v,
            r,
            s
        );
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
    nonReentrant
    public {
        checkGaslessBlacklist(_msgSender(), feeRecipient);

        _storage.validateOffChainPermit(domainSeparator, PERMIT_TYPE_HASH, owner, spender, nonce, expiry, allowed, feeAmount, feeRecipient, v, r, s);

        uint wad = allowed ? uint(- 1) : 0;
        _approve(owner, spender, wad);

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
    nonReentrant
    public {
        checkGaslessBlacklist(_msgSender(), feeRecipient);

        _storage.validateOffChainTransfer(domainSeparator, TRANSFER_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient, v, r, s);

        uint amountLessFee = amount.sub(feeAmount, "FEE_TOO_LARGE");
        _transfer(owner, recipient, amountLessFee);
        doFeeTransferForDmmIfNecessary(owner, feeRecipient, feeAmount);
    }

    /************************************
     * Private & Internal Functions
     */

    function _mint(address owner, address recipient, uint underlyingAmount) internal returns (uint) {
        blacklistable().checkNotBlacklisted(_msgSender());

        uint currentExchangeRate = this.updateExchangeRateIfNecessaryAndGet(_storage);
        uint amount = underlyingAmount.underlyingToAmount(currentExchangeRate, EXCHANGE_RATE_BASE_RATE);

        require(balanceOf(address(this)) >= amount, "INSUFFICIENT_DMM_LIQUIDITY");

        // Transfer underlying to this contract
        transferUnderlyingIn(owner, underlyingAmount);

        // Transfer DMM to the recipient
        blacklistable().checkNotBlacklisted(owner);
        _transfer(address(this), recipient, amount);

        emit Mint(owner, recipient, amount);

        require(amount >= minMintAmount, "INSUFFICIENT_MINT_AMOUNT");

        return amount;
    }

    /**
     * @dev Note, right now all invocations of this function set `shouldUseAllowance` to `false`. Reason being, all
     *      calls are either done via explicit off-chain signatures (and therefore the owner and recipient are explicit;
     *      anyone can call the function), OR the msgSender is both the owner and recipient, in which case no allowance
     *      should be needed to redeem funds if the user is the spender of the same user's funds.
     */
    function _redeem(address owner, address recipient, uint amount, bool shouldUseAllowance) internal returns (uint) {
        blacklistable().checkNotBlacklisted(_msgSender());
        blacklistable().checkNotBlacklisted(recipient);

        uint currentExchangeRate = this.updateExchangeRateIfNecessaryAndGet(_storage);
        uint underlyingAmount = amount.amountToUnderlying(currentExchangeRate, EXCHANGE_RATE_BASE_RATE);

        IERC20 underlyingToken = IERC20(this.controller().getUnderlyingTokenForDmm(address(this)));
        require(underlyingToken.balanceOf(address(this)) >= underlyingAmount, "INSUFFICIENT_UNDERLYING_LIQUIDITY");

        if (shouldUseAllowance) {
            uint newAllowance = allowance(owner, _msgSender()).sub(amount, "INSUFFICIENT_ALLOWANCE");
            _approve(owner, _msgSender(), newAllowance);
        }
        _transfer(owner, address(this), amount);

        // Transfer underlying to the recipient from this contract
        transferUnderlyingOut(recipient, amount);

        emit Redeem(owner, recipient, amount);

        require(amount >= minRedeemAmount, "INSUFFICIENT_REDEEM_AMOUNT");

        return underlyingAmount;
    }

    function _mintFromGaslessRequest(
        address owner,
        address recipient,
        uint nonce,
        uint expiry,
        uint underlyingAmount,
        uint feeAmount,
        address feeRecipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal returns (uint) {
        checkGaslessBlacklist(_msgSender(), feeRecipient);

        // To avoid stack too deep issues, splitting the call into 2 parts is essential.
        _storage.validateOffChainMint(domainSeparator, MINT_TYPE_HASH, owner, recipient, nonce, expiry, underlyingAmount, feeAmount, feeRecipient, v, r, s);

        // Initially, we mint to this contract so we can send handle the fees.
        // We don't delegate the call for transferring the underlying in, because gasless requests are designed to
        // allow any relayer to broadcast the user's cryptographically-secure message.
        uint amount = _mint(owner, address(this), underlyingAmount);
        require(amount >= feeAmount, "FEE_TOO_LARGE");

        uint amountLessFee = amount.sub(feeAmount);
        require(amountLessFee >= minMintAmount, "INSUFFICIENT_MINT_AMOUNT");

        _transfer(address(this), recipient, amountLessFee);

        doFeeTransferForDmmIfNecessary(address(this), feeRecipient, feeAmount);

        return amountLessFee;
    }

    function _redeemFromGaslessRequest(
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
    ) internal returns (uint) {
        checkGaslessBlacklist(_msgSender(), feeRecipient);

        // To avoid stack too deep issues, splitting the call into 2 parts is essential.
        _storage.validateOffChainRedeem(domainSeparator, REDEEM_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient, v, r, s);

        uint amountLessFee = amount.sub(feeAmount, "FEE_TOO_LARGE");
        require(amountLessFee >= minRedeemAmount, "INSUFFICIENT_REDEEM_AMOUNT");

        uint underlyingAmount = _redeem(owner, recipient, amountLessFee, /* shouldUseAllowance */ false);
        doFeeTransferForDmmIfNecessary(owner, feeRecipient, feeAmount);

        return underlyingAmount;
    }

    function checkGaslessBlacklist(address msgSender, address feeRecipient) private view {
        blacklistable().checkNotBlacklisted(msgSender);
        if (feeRecipient != address(0x0)) {
            blacklistable().checkNotBlacklisted(feeRecipient);
        }
    }

    function doFeeTransferForDmmIfNecessary(address owner, address feeRecipient, uint feeAmount) private {
        if (feeAmount > 0) {
            require(balanceOf(owner) >= feeAmount, "INSUFFICIENT_BALANCE_FOR_FEE");
            _transfer(owner, feeRecipient, feeAmount);
            emit FeeTransfer(owner, feeRecipient, feeAmount);
        }
    }

}
