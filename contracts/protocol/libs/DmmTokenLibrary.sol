pragma solidity ^0.5.0;

import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../constants/CommonConstants.sol";
import "../interfaces/IDmmToken.sol";

library DmmTokenLibrary {

    using SafeERC20 for IERC20;
    using SafeMath for uint;

    /*****************
     * Structs
     */

    struct Storage {
        uint exchangeRate;
        uint exchangeRateLastUpdatedTimestamp;
        uint exchangeRateLastUpdatedBlockNumber;
        mapping(address => uint) nonces;
    }

    /*****************
     * Events
     */

    event Mint(address indexed minter, address indexed recipient, uint amount);
    event Redeem(address indexed redeemer, address indexed recipient, uint amount);
    event FeeTransfer(address indexed owner, address indexed recipient, uint amount);

    event OffChainRequestValidated(address indexed owner, address indexed feeRecipient, uint nonce, uint expiry, uint feeAmount);

    /*****************
     * Public Constants
     */

    uint public constant INTEREST_RATE_BASE = 1e18;
    uint public constant SECONDS_IN_YEAR = 31536000; // 60 * 60 * 24 * 365

    /**********************
     * Public Functions
     */

    function amountToUnderlying(uint amount, uint exchangeRate, uint exchangeRateBaseRate) internal pure returns (uint) {
        return (amount.mul(exchangeRate)).div(exchangeRateBaseRate);
    }

    function underlyingToAmount(uint underlyingAmount, uint exchangeRate, uint exchangeRateBaseRate) internal pure returns (uint) {
        return (underlyingAmount.mul(exchangeRateBaseRate)).div(exchangeRate);
    }

    function accrueInterest(uint exchangeRate, uint interestRate, uint _seconds) internal pure returns (uint) {
        uint interestAccrued = INTEREST_RATE_BASE.add(((interestRate.mul(_seconds)).div(SECONDS_IN_YEAR)));
        return (exchangeRate.mul(interestAccrued)).div(INTEREST_RATE_BASE);
    }

    /***************************
     * Internal User Functions
     */

    function getCurrentExchangeRate(Storage storage _storage, uint interestRate) internal view returns (uint) {
        if (_storage.exchangeRateLastUpdatedTimestamp >= block.timestamp) {
            // The exchange rate has not changed yet
            return _storage.exchangeRate;
        } else {
            uint diffInSeconds = block.timestamp.sub(_storage.exchangeRateLastUpdatedTimestamp, "INVALID_BLOCK_TIMESTAMP");
            return accrueInterest(_storage.exchangeRate, interestRate, diffInSeconds);
        }
    }

    function updateExchangeRateIfNecessaryAndGet(IDmmToken token, Storage storage _storage) internal returns (uint) {
        uint previousExchangeRate = _storage.exchangeRate;
        uint dmmTokenInterestRate = token.controller().getInterestRateByDmmTokenAddress(address(token));
        uint currentExchangeRate = getCurrentExchangeRate(_storage, dmmTokenInterestRate);
        if (currentExchangeRate != previousExchangeRate) {
            _storage.exchangeRateLastUpdatedTimestamp = block.timestamp;
            _storage.exchangeRateLastUpdatedBlockNumber = block.number;
            _storage.exchangeRate = currentExchangeRate;
            return currentExchangeRate;
        } else {
            return currentExchangeRate;
        }
    }

    function validateOffChainMint(
        Storage storage _storage,
        bytes32 domainSeparator,
        bytes32 typeHash,
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
                keccak256(abi.encode(typeHash, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0), "CANNOT_MINT_FROM_ZERO_ADDRESS");
        require(recipient != address(0), "CANNOT_MINT_TO_ZERO_ADDRESS");
        validateOffChainRequest(_storage, digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    function validateOffChainRedeem(
        Storage storage _storage,
        bytes32 domainSeparator,
        bytes32 typeHash,
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
                keccak256(abi.encode(typeHash, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0), "CANNOT_REDEEM_FROM_ZERO_ADDRESS");
        require(recipient != address(0), "CANNOT_REDEEM_TO_ZERO_ADDRESS");
        validateOffChainRequest(_storage, digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    function validateOffChainPermit(
        Storage storage _storage,
        bytes32 domainSeparator,
        bytes32 typeHash,
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
                keccak256(abi.encode(typeHash, owner, spender, nonce, expiry, allowed, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0), "CANNOT_APPROVE_FROM_ZERO_ADDRESS");
        require(spender != address(0), "CANNOT_APPROVE_TO_ZERO_ADDRESS");
        validateOffChainRequest(_storage, digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    function validateOffChainTransfer(
        Storage storage _storage,
        bytes32 domainSeparator,
        bytes32 typeHash,
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
                keccak256(abi.encode(typeHash, owner, recipient, nonce, expiry, amount, feeAmount, feeRecipient))
            )
        );

        require(owner != address(0x0), "CANNOT_TRANSFER_FROM_ZERO_ADDRESS");
        require(recipient != address(0x0), "CANNOT_TRANSFER_TO_ZERO_ADDRESS");
        validateOffChainRequest(_storage, digest, owner, nonce, expiry, feeAmount, feeRecipient, v, r, s);
    }

    /***************************
     * Internal Admin Functions
     */

    function _depositUnderlying(IDmmToken token, address sender, uint underlyingAmount) internal returns (bool) {
        IERC20 underlyingToken = IERC20(token.controller().getUnderlyingTokenForDmm(address(token)));
        underlyingToken.safeTransferFrom(sender, address(token), underlyingAmount);
        return true;
    }

    function _withdrawUnderlying(IDmmToken token, address sender, uint underlyingAmount) internal returns (bool) {
        IERC20 underlyingToken = IERC20(token.controller().getUnderlyingTokenForDmm(address(token)));
        underlyingToken.safeTransfer(sender, underlyingAmount);
        return true;
    }

    /***************************
     * Private Functions
     */

    /**
     * @dev throws if the validation fails
     */
    function validateOffChainRequest(
        Storage storage _storage,
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
        uint expectedNonce = _storage.nonces[owner];

        require(owner == ecrecover(digest, v, r, s), "INVALID_SIGNATURE");
        require(expiry == 0 || now <= expiry, "REQUEST_EXPIRED");
        require(nonce == expectedNonce, "INVALID_NONCE");
        if (feeAmount > 0) {
            require(feeRecipient != address(0x0), "INVALID_FEE_ADDRESS");
        }

        emit OffChainRequestValidated(
            owner,
            feeRecipient,
            expectedNonce,
            expiry,
            feeAmount
        );
        _storage.nonces[owner] += 1;
    }

}
