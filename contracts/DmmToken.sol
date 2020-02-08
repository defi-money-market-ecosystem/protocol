pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./libs/AssemblyHelpers.sol";
import "./libs/Blacklistable.sol";
import "./libs/ERC20.sol";
import "./libs/IDmmController.sol";
import "./libs/IDmmToken.sol";

contract DmmToken is ERC20, Ownable, IDmmToken, AssemblyHelpers {

    using SafeERC20 for IERC20;
    using SafeMath for uint;

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

    uint private _exchangeRateLastUpdatedTimestamp;
    mapping(address => uint) public nonces;

    uint private _exchangeRate;

    constructor(
        string memory _symbol,
        string memory _name,
        uint8 _decimals,
        uint _minMintAmount,
        uint _minRedeemAmount,
        uint _totalSupply,
        address _controller
    ) public {
//        symbol = _symbol;
//        name = _name;
//        decimals = _decimals;
//        minMintAmount = _minMintAmount;
//        minRedeemAmount = _minRedeemAmount;
//        controller = IDmmController(_controller);
//
//        domainSeparator = keccak256(abi.encode(
//                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
//                keccak256(bytes(name)),
//                keccak256(bytes(/* version */ "1")),
//                chainId(),
//                address(this)
//            ));
//
//        _exchangeRate = EXCHANGE_RATE_BASE_RATE;
//        _exchangeRateLastUpdatedTimestamp = block.timestamp;
//
//         mintToThisContract(_totalSupply);
    }

    /********************
     * Modifiers
     */

    modifier isNotDisabled {
        require(controller.isMarketEnabled(address(this)), MARKET_DISABLED);
        _;
    }

    /********************
     * Public Functions
     */

    function() external {
        revert(NO_DEFAULT_FUNCTION);
    }

    function pausable() public view returns (address) {
        return address(controller);
    }

    function blacklistable() public view returns (address) {
        return address(controller.blacklistable());
    }

    function activeSupply() public view returns (uint) {
        return totalSupply().sub(balanceOf(address(this)));
    }

    function increaseTotalSupply(uint amount) public onlyOwner whenNotPaused {
        mintToThisContract(amount);
    }

    function decreaseTotalSupply(uint amount) public onlyOwner whenNotPaused {
        // If there's underflow, throw the specified error
        balanceOf(address(this)).sub(amount, TOO_MUCH_ACTIVE_SUPPLY);
        burnFromThisContract(amount);
    }

    function depositUnderlying(uint underlyingAmount) onlyOwner whenNotPaused public returns (bool) {
        IERC20 underlyingToken = IERC20(controller.getUnderlyingTokenForDmm(address(this)));
        underlyingToken.safeTransferFrom(_msgSender(), address(this), underlyingAmount);
        emit AdminDeposit(underlyingAmount);
        return true;
    }

    function withdrawUnderlying(uint underlyingAmount) onlyOwner whenNotPaused public returns (bool) {
        IERC20 underlyingToken = IERC20(controller.getUnderlyingTokenForDmm(address(this)));
        underlyingToken.safeTransfer(_msgSender(), underlyingAmount);
        emit AdminWithdraw(underlyingAmount);
        return true;
    }

    function exchangeRate() public view returns (uint) {
        if (_exchangeRateLastUpdatedTimestamp >= block.timestamp) {
            // The exchange rate has not changed yet
            return _exchangeRate;
        } else {
            uint diffInSeconds = block.timestamp.sub(_exchangeRateLastUpdatedTimestamp, INVALID_BLOCK_TIMESTAMP);
            uint interestRate = controller.getInterestRate(address(this));
            uint amountToAdd = controller.INTEREST_RATE_BASE().add(((interestRate.mul(diffInSeconds)).div(SECONDS_IN_YEAR)));
            return (_exchangeRate.mul(amountToAdd)).div(controller.INTEREST_RATE_BASE());
        }
    }

    function exchangeRateLastUpdatedTimestamp() public view returns (uint) {
        return _exchangeRateLastUpdatedTimestamp;
    }

    function nonceOf(address owner) public view returns (uint) {
        return nonces[owner];
    }

    function mintFromUnderlying(
        uint amountUnderlying
    )
    whenNotPaused
    notBlacklisted(_msgSender())
    public returns (uint) {
        (,uint amount) = mintDmmFromUnderlyingAmountInternal(_msgSender(), _msgSender(), amountUnderlying);
        require(amount >= minMintAmount, INSUFFICIENT_MINT_AMOUNT);
        return amount;
    }

    function mint(
        uint amount
    )
    whenNotPaused
    notBlacklisted(_msgSender())
    public returns (uint) {
        (uint underlyingAmount,) = mintDmmFromAmountInternal(_msgSender(), _msgSender(), amount);
        require(amount >= minMintAmount, INSUFFICIENT_MINT_AMOUNT);
        return underlyingAmount;
    }

    function mintFromUnderlyingFrom(
        uint amountUnderlying,
        address sender,
        address recipient
    )
    whenNotPaused
    notBlacklisted(_msgSender())
    notBlacklisted(sender)
    notBlacklisted(recipient)
    public returns (uint) {
        (,uint amount) = mintDmmFromUnderlyingAmountInternal(sender, recipient, amountUnderlying);
        require(amount >= minMintAmount, INSUFFICIENT_MINT_AMOUNT);
        return amount;
    }

    function mintFrom(
        uint amount,
        address sender,
        address recipient
    )
    whenNotPaused
    notBlacklisted(_msgSender())
    notBlacklisted(sender)
    notBlacklisted(recipient)
    public returns (uint) {
        (uint underlyingAmount,) = mintDmmFromAmountInternal(sender, recipient, amount);
        require(amount >= minMintAmount, INSUFFICIENT_MINT_AMOUNT);
        return underlyingAmount;
    }

    function mint(
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
    notBlacklisted(_msgSender())
    notBlacklisted(owner)
    notBlacklisted(recipient)
    public returns (uint) {
        // To avoid stack too deep issues, splitting the call into 2 parts is essential.
        mintPart1(owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient, v, r, s);
        return mintPart2(owner, recipient, amount, feeAmount, feeRecipient);
    }

    function mintPart1(
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
    ) private {
        bytes32 digest =
        keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(MINT_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0), CANNOT_MINT_FROM_ZERO_ADDRESS);
        require(recipient != address(0), CANNOT_MINT_TO_ZERO_ADDRESS);
        validateOffChainRequest(digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    function mintPart2(
        address owner,
        address recipient,
        uint amount,
        uint feeAmount,
        address feeRecipient
    ) private returns (uint) {
        (,uint amountReceived) = mintDmmFromAmountInternal(owner, recipient, amount.sub(feeAmount, FEE_TOO_LARGE));
        doFeeTransferForDmmIfNecessary(owner, feeRecipient, feeAmount);
        require(amount >= minMintAmount, INSUFFICIENT_MINT_AMOUNT);

        return amountReceived;
    }

    function redeemFromUnderlying(
        uint amountUnderlying
    )
    whenNotPaused
    notBlacklisted(_msgSender())
    public returns (uint) {
        (,uint amount) = redeemDmmFromUnderlyingAmountInternal(_msgSender(), _msgSender(), amountUnderlying);
        require(amount >= minRedeemAmount, INSUFFICIENT_REDEEM_AMOUNT);
        return amount;
    }

    function redeem(
        uint amount
    )
    whenNotPaused
    notBlacklisted(_msgSender())
    public returns (uint) {
        (uint underlyingAmount,) = redeemDmmFromAmountInternal(_msgSender(), _msgSender(), amount);
        require(amount >= minRedeemAmount, INSUFFICIENT_REDEEM_AMOUNT);
        return underlyingAmount;
    }

    function redeemFromUnderlyingFrom(
        uint amountUnderlying,
        address sender,
        address recipient
    )
    whenNotPaused
    notBlacklisted(_msgSender())
    notBlacklisted(sender)
    notBlacklisted(recipient)
    public returns (uint) {
        (,uint amount) = redeemDmmFromUnderlyingAmountInternal(sender, recipient, amountUnderlying);
        require(amount >= minRedeemAmount, INSUFFICIENT_REDEEM_AMOUNT);
        return amount;
    }

    function redeemFrom(
        uint amount,
        address sender,
        address recipient
    )
    whenNotPaused
    notBlacklisted(_msgSender())
    notBlacklisted(sender)
    notBlacklisted(recipient)
    public returns (uint) {
        (uint underlyingAmount,) = redeemDmmFromAmountInternal(sender, recipient, amount);
        require(amount >= minRedeemAmount, INSUFFICIENT_REDEEM_AMOUNT);
        return underlyingAmount;
    }

    function redeem(
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
    notBlacklisted(_msgSender())
    notBlacklisted(owner)
    notBlacklisted(recipient)
    public returns (uint) {
        // To avoid stack too deep issues, splitting the call into 2 parts is essential.
        redeemPart1(owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient, v, r, s);
        return redeemPart2(owner, recipient, amount, feeAmount, feeRecipient);
    }

    function redeemPart1(
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
    ) private {
        bytes32 digest =
        keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(REDEEM_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0), CANNOT_REDEEM_FROM_ZERO_ADDRESS);
        require(recipient != address(0), CANNOT_REDEEM_TO_ZERO_ADDRESS);
        validateOffChainRequest(digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    function redeemPart2(
        address owner,
        address recipient,
        uint amount,
        uint feeAmount,
        address feeRecipient
    ) private returns (uint) {
        uint amountLessFee = amount.sub(feeAmount, FEE_TOO_LARGE);
        (uint underlyingAmount,) = redeemDmmFromAmountInternal(owner, recipient, amountLessFee);
        doFeeTransferForDmmIfNecessary(owner, feeRecipient, feeAmount);
        require(amount >= minRedeemAmount, INSUFFICIENT_REDEEM_AMOUNT);

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
    notBlacklisted(_msgSender())
    notBlacklisted(owner)
    notBlacklisted(spender)
    public {
        bytes32 digest =
        keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(PERMIT_TYPE_HASH, owner, spender, nonce, expiry, allowed, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0), CANNOT_APPROVE_FROM_ZERO_ADDRESS);
        require(spender != address(0), CANNOT_APPROVE_TO_ZERO_ADDRESS);
        validateOffChainRequest(digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);

        uint wad = allowed ? uint(- 1) : 0;
        _approve(owner, spender, wad);

        doFeeTransferForDmmIfNecessary(owner, feeRecipient, feeAmount);
    }

    function transfer(
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
    notBlacklisted(_msgSender())
    notBlacklisted(owner)
    notBlacklisted(recipient)
    public {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(TRANSFER_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0x0), CANNOT_TRANSFER_FROM_ZERO_ADDRESS);
        require(recipient != address(0x0), CANNOT_TRANSFER_TO_ZERO_ADDRESS);
        validateOffChainRequest(digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);

        _transfer(owner, recipient, amount.sub(feeAmount, FEE_TOO_LARGE));
        doFeeTransferForDmmIfNecessary(owner, feeRecipient, feeAmount);
    }

    /************************************
     * Private & Internal Functions
     */

    function mintDmmFromAmountInternal(address owner, address recipient, uint amount) private returns (uint, uint) {
        uint currentExchangeRate = updateExchangeRateIfNecessaryAndGet();
        uint underlyingAmount = (amount.mul(EXCHANGE_RATE_BASE_RATE)).div(currentExchangeRate);
        return mintDmmInternal(owner, recipient, amount, underlyingAmount);
    }

    function mintDmmFromUnderlyingAmountInternal(address owner, address recipient, uint underlyingAmount) private returns (uint, uint) {
        uint currentExchangeRate = updateExchangeRateIfNecessaryAndGet();
        uint amount = (underlyingAmount.mul(currentExchangeRate)).div(EXCHANGE_RATE_BASE_RATE);
        return mintDmmInternal(owner, recipient, amount, underlyingAmount);
    }

    function redeemDmmFromAmountInternal(address owner, address recipient, uint amount) private returns (uint, uint) {
        uint currentExchangeRate = updateExchangeRateIfNecessaryAndGet();
        uint underlyingAmount = (amount.mul(EXCHANGE_RATE_BASE_RATE)).div(currentExchangeRate);
        return redeemDmmInternal(owner, recipient, amount, underlyingAmount);
    }

    function redeemDmmFromUnderlyingAmountInternal(address owner, address recipient, uint underlyingAmount) private returns (uint, uint) {
        uint currentExchangeRate = updateExchangeRateIfNecessaryAndGet();
        uint amount = (underlyingAmount.mul(currentExchangeRate)).div(EXCHANGE_RATE_BASE_RATE);
        return redeemDmmInternal(owner, recipient, amount, underlyingAmount);
    }

    function mintDmmInternal(address owner, address recipient, uint amount, uint underlyingAmount) private returns (uint, uint) {
        require(balanceOf(address(this)) >= amount, INSUFFICIENT_DMM_LIQUIDITY);

        // Transfer underlying to this contract
        IERC20(controller.getUnderlyingTokenForDmm(address(this))).safeTransferFrom(owner, address(this), underlyingAmount);

        // Transfer DMM to the recipient
        _transfer(address(this), recipient, amount);

        emit Mint(owner, recipient, amount);

        return (underlyingAmount, amount);
    }

    function redeemDmmInternal(address owner, address recipient, uint amount, uint underlyingAmount) private returns (uint, uint) {
        IERC20 underlyingToken = IERC20(controller.getUnderlyingTokenForDmm(address(this)));
        require(underlyingToken.balanceOf(address(this)) >= underlyingAmount, INSUFFICIENT_UNDERLYING_LIQUIDITY);

        // Transfer DMM to this contract from whoever _msgSender() is
        transferFrom(owner, address(this), amount);

        // Transfer underlying to the recipient from this contract
        underlyingToken.safeTransfer(recipient, underlyingAmount);

        emit Redeem(owner, recipient, amount);

        return (underlyingAmount, amount);
    }

    function updateExchangeRateIfNecessaryAndGet() private returns (uint) {
        uint previousExchangeRate = _exchangeRate;
        uint currentExchangeRate = exchangeRate();
        if (currentExchangeRate != previousExchangeRate) {
            _exchangeRateLastUpdatedTimestamp = block.timestamp;
            _exchangeRate = currentExchangeRate;
            return currentExchangeRate;
        } else {
            return currentExchangeRate;
        }
    }

    /**
     * @dev throws if the validation fails
     */
    function validateOffChainRequest(
        bytes32 digest,
        address owner,
        uint nonce,
        uint expiry,
        uint feeAmount,
        address feeRecipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private {
        require(owner == ecrecover(digest, v, r, s), INVALID_SIGNATURE);
        require(expiry == 0 || now <= expiry, REQUEST_EXPIRED);
        require(nonce == nonces[owner]++, INVALID_NONCE);
        if (feeAmount > 0) {
            require(feeRecipient != address(0x0), INVALID_FEE_ADDRESS);
        }
    }

    function doFeeTransferForDmmIfNecessary(address owner, address feeRecipient, uint feeAmount) private {
        if (feeAmount > 0) {
            approveThisContractIfNecessary(owner);
            IERC20(address(this)).safeTransferFrom(owner, feeRecipient, feeAmount);
            emit FeeTransfer(owner, feeRecipient, feeAmount);
        }
    }

    function approveThisContractIfNecessary(address owner) private {
        if (allowance(owner, address(this)) == 0) {
            _approve(owner, address(this), uint(- 1));
        }
    }

}
