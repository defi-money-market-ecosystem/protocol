pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../DmmToken.sol";
import "../constants/CommonConstants.sol";
import "../interfaces/IDmmToken.sol";

library DmmTokenLibrary {

    using SafeERC20 for IERC20;
    using SafeMath for uint;

    /*****************
     * Events
     */

    event Mint(address indexed minter, address indexed recipient, uint amount);
    event Redeem(address indexed redeemer, address indexed recipient, uint amount);
    event FeeTransfer(address indexed owner, address indexed recipient, uint amount);

    event AdminDeposit(uint amount);
    event AdminWithdraw(uint amount);

    /*****************
     * Public Constants
     */

    uint public constant EXCHANGE_RATE_BASE_RATE = 1e18;
    uint public constant INTEREST_RATE_BASE = 1e18;
    uint public constant SECONDS_IN_YEAR = 31536000; // 60 * 60 * 24 * 365

    // bytes32 public constant PERMIT_TYPE_HASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant permitTypeHash = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant PERMIT_TYPE_HASH = 0x0000000000000000000000000000000000000000000000000000000000000000;

    // bytes32 public constant TRANSFER_TYPE_HASH = keccak256("Transfer(address owner,address recipient,uint256 nonce,uint256 expiry,uint amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant transferTypeHash = keccak256("Transfer(address owner,address recipient,uint256 nonce,uint256 expiry,uint amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant TRANSFER_TYPE_HASH = 0x0000000000000000000000000000000000000000000000000000000000000000;

    // bytes32 public constant MINT_TYPE_HASH = keccak256("Mint(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant mintTypeHash = keccak256("Mint(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant MINT_TYPE_HASH = 0x0000000000000000000000000000000000000000000000000000000000000000;

    // bytes32 public constant REDEEM_TYPE_HASH = keccak256("Redeem(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant redeemTypeHash = keccak256("Redeem(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant REDEEM_TYPE_HASH = 0x0000000000000000000000000000000000000000000000000000000000000000;

    /********************
     * Modifiers
     */

    /*****************
     * Getters
     */

    function getMintTypeHash() public pure returns (bytes32) {
        return MINT_TYPE_HASH;
    }

    function getPermitTypeHash() public pure returns (bytes32) {
        return PERMIT_TYPE_HASH;
    }

    function getRedeemTypeHash() public pure returns (bytes32) {
        return REDEEM_TYPE_HASH;
    }

    function getTransferTypeHash() public pure returns (bytes32) {
        return TRANSFER_TYPE_HASH;
    }

    function getExchangeRateBaseRate() public pure returns (uint) {
        return EXCHANGE_RATE_BASE_RATE;
    }

    function getInterestRateBase() public pure returns (uint) {
        return INTEREST_RATE_BASE;
    }

    function getSecondsInYear() public pure returns (uint) {
        return SECONDS_IN_YEAR;
    }

    /**********************
     * Public Functions
     */

    function amountToUnderlying(uint amount, uint exchangeRate) internal pure returns (uint) {
        return (amount.mul(exchangeRate)).div(EXCHANGE_RATE_BASE_RATE);
    }

    function underlyingToAmount(uint underlyingAmount, uint exchangeRate) internal pure returns (uint) {
        return (underlyingAmount.mul(EXCHANGE_RATE_BASE_RATE)).div(exchangeRate);
    }

    function accrueInterest(uint exchangeRate, uint interestRate, uint _seconds) internal pure returns (uint) {
        uint interestAccrued = INTEREST_RATE_BASE.add(((interestRate.mul(_seconds)).div(SECONDS_IN_YEAR)));
        return (exchangeRate.mul(interestAccrued)).div(INTEREST_RATE_BASE);
    }

    /***************************
     * Public User Functions
     */

    /***************************
     * Internal User Functions
     */

    function getCurrentExchangeRate(IDmmToken.Storage storage _storage, uint interestRate) internal view returns (uint) {
        if (_storage.exchangeRateLastUpdatedTimestamp >= block.timestamp) {
            // The exchange rate has not changed yet
            return _storage.exchangeRate;
        } else {
            uint diffInSeconds = block.timestamp.sub(_storage.exchangeRateLastUpdatedTimestamp, "INVALID_BLOCK_TIMESTAMP");
            return accrueInterest(_storage.exchangeRate, interestRate, diffInSeconds);
        }
    }

    function updateExchangeRateIfNecessaryAndGet(DmmToken token, IDmmToken.Storage storage _storage) internal returns (uint) {
        uint previousExchangeRate = _storage.exchangeRate;
        uint currentExchangeRate = getCurrentExchangeRate(_storage, token.controller().getInterestRate(address(token)));
        if (currentExchangeRate != previousExchangeRate) {
            _storage.exchangeRateLastUpdatedTimestamp = block.timestamp;
            _storage.exchangeRate = currentExchangeRate;
            return currentExchangeRate;
        } else {
            return currentExchangeRate;
        }
    }

    function validateOffChainMint(
        IDmmToken.Storage storage _storage,
        bytes32 domainSeparator,
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
    ) internal {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(MINT_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0), "CANNOT_MINT_FROM_ZERO_ADDRESS");
        require(recipient != address(0), "CANNOT_MINT_TO_ZERO_ADDRESS");
        validateOffChainRequest(_storage, digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    function validateOffChainRedeem(
        IDmmToken.Storage storage _storage,
        bytes32 domainSeparator,
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
    ) internal {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(REDEEM_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0), "CANNOT_REDEEM_FROM_ZERO_ADDRESS");
        require(recipient != address(0), "CANNOT_REDEEM_TO_ZERO_ADDRESS");
        validateOffChainRequest(_storage, digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    function validateOffChainPermit(
        IDmmToken.Storage storage _storage,
        bytes32 domainSeparator,
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
    ) internal {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(PERMIT_TYPE_HASH, owner, spender, nonce, expiry, allowed, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0), "CANNOT_APPROVE_FROM_ZERO_ADDRESS");
        require(spender != address(0), "CANNOT_APPROVE_TO_ZERO_ADDRESS");
        validateOffChainRequest(_storage, digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    function validateOffChainTransfer(
        IDmmToken.Storage storage _storage,
        bytes32 domainSeparator,
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
    ) internal {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(abi.encode(TRANSFER_TYPE_HASH, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0x0), "CANNOT_TRANSFER_FROM_ZERO_ADDRESS");
        require(recipient != address(0x0), "CANNOT_TRANSFER_TO_ZERO_ADDRESS");
        validateOffChainRequest(_storage, digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    function _mintDmm(DmmToken token, address owner, address recipient, uint amount, uint underlyingAmount) internal {
        require(token.balanceOf(address(this)) >= amount, "INSUFFICIENT_DMM_LIQUIDITY");

        // Transfer underlying to this contract
        IERC20(token.controller().getUnderlyingTokenForDmm(address(this))).safeTransferFrom(owner, address(this), underlyingAmount);

        // Transfer DMM to the recipient
        token.transfer(recipient, amount);

        emit Mint(owner, recipient, amount);
    }

    function _redeemDmm(DmmToken token, address owner, address recipient, uint amount, uint underlyingAmount) internal {
        IERC20 underlyingToken = IERC20(token.controller().getUnderlyingTokenForDmm(address(this)));
        require(underlyingToken.balanceOf(address(this)) >= underlyingAmount, "INSUFFICIENT_UNDERLYING_LIQUIDITY");

        // Transfer DMM to this contract from whoever _msgSender() is
        token.transferFrom(owner, address(this), amount);

        // Transfer underlying to the recipient from this contract
        underlyingToken.safeTransfer(recipient, underlyingAmount);

        emit Redeem(owner, recipient, amount);
    }

    /***************************
     * Internal Admin Functions
     */

    function _depositUnderlying(DmmToken token, address sender, uint underlyingAmount) internal returns (bool) {
        IERC20 underlyingToken = IERC20(token.controller().getUnderlyingTokenForDmm(address(this)));
        underlyingToken.safeTransferFrom(sender, address(this), underlyingAmount);
        emit AdminDeposit(underlyingAmount);
        return true;
    }

    function _withdrawUnderlying(DmmToken token, address sender, uint underlyingAmount) internal returns (bool) {
        IERC20 underlyingToken = IERC20(token.controller().getUnderlyingTokenForDmm(address(this)));
        underlyingToken.safeTransfer(sender, underlyingAmount);
        emit AdminWithdraw(underlyingAmount);
        return true;
    }

    /***************************
     * Private Functions
     */

    /**
     * @dev throws if the validation fails
     */
    function validateOffChainRequest(
        IDmmToken.Storage storage _storage,
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
        require(owner == ecrecover(digest, v, r, s), "INVALID_SIGNATURE");
        require(expiry == 0 || now <= expiry, "REQUEST_EXPIRED");
        require(nonce == _storage.nonces[owner]++, "INVALID_NONCE");
        if (feeAmount > 0) {
            require(feeRecipient != address(0x0), "INVALID_FEE_ADDRESS");
        }
    }

}
