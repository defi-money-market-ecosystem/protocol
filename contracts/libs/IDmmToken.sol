pragma solidity ^0.5.0;

/**
 * Basically an interface except, contains the implementation of the type-hashes for offline signature generation.
 *
 * This contract contains the signatures and documentation for all publicly-implemented functions in the DMM token.
 */
contract IDmmToken {

    event AdminDeposit(uint amount);
    event AdminWithdraw(uint amount);

    event Mint(address indexed minter, address indexed recipient, uint amount);
    event Redeem(address indexed redeemer, address indexed recipient, uint amount);

    event FeeTransfer(address indexed owner, address indexed recipient, uint amount);

    uint constant public SECONDS_IN_YEAR = 31536000; // 60 * 60 * 24 * 365

    uint constant public EXCHANGE_RATE_BASE_RATE = 1e18;

    // bytes32 public constant PERMIT_TYPE_HASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed,uint256 feeAmount,address feeRecipient)");
    bytes32 public permitTypeHash = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant PERMIT_TYPE_HASH = 0x0000000000000000000000000000000000000000000000000000000000000000;

    // bytes32 public constant TRANSFER_TYPE_HASH = keccak256("Transfer(address owner,address recipient,uint256 nonce,uint256 expiry,uint amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public transferTypeHash = keccak256("Transfer(address owner,address recipient,uint256 nonce,uint256 expiry,uint amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant TRANSFER_TYPE_HASH = 0x0000000000000000000000000000000000000000000000000000000000000000;

    // bytes32 public constant MINT_TYPE_HASH = keccak256("Mint(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public mintTypeHash = keccak256("Mint(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant MINT_TYPE_HASH = 0x0000000000000000000000000000000000000000000000000000000000000000;

    // bytes32 public constant REDEEM_TYPE_HASH = keccak256("Redeem(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public redeemTypeHash = keccak256("Redeem(address owner,address recipient,uint256 nonce,uint256 expiry,uint256 amount,uint256 feeAmount,address feeRecipient)");
    bytes32 public constant REDEEM_TYPE_HASH = 0x0000000000000000000000000000000000000000000000000000000000000000;

    /**
     * @dev The controller that deployed this parent
     */
    function controller() external view returns (address);

    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external view returns (uint8);

    /**
     * @return  The min amount that can be minted in a single transaction. This amount corresponds with the number of
     *          decimals that this token has.
     */
    function minMintAmount() external view returns (uint);

    /**
     * @return  The min amount that can be redeemed from DMM to underlying in a single transaction. This amount
     *          corresponds with the number of decimals that this token has.
     */
    function minRedeemAmount() external view returns (uint);

    /**
      * @dev The amount of DMM that is in circulation (outside of this contract)
      */
    function activeSupply() external view returns (uint);

    /**
     * @dev Attempts to add `amount` to the total supply by issuing the tokens to this contract. This call fires a
     *      Transfer event from the 0x0 address to this contract.
     */
    function increaseTotalSupply(uint amount) external;

    /**
     * @dev Attempts to remove `amount` from the total supply by destroying those tokens that are held in this
     *      contract. This call reverts with TOO_MUCH_ACTIVE_SUPPLY if `amount` is not held in this contract.
     */
    function decreaseTotalSupply(uint amount) external;

    /**
     * @dev An admin function that lets the ecosystem's organizers deposit the underlying token around which this DMMA
     *      wraps to this contract. This is used to replenish liquidity and after interest payouts are made from the
     *      real-world assets.
     */
    function depositUnderlying(uint underlyingAmount) external returns (bool);

    /**
     * @dev An admin function that lets the ecosystem's organizers withdraw the underlying token around which this DMMA
     *      wraps from this contract. This is used to withdraw deposited tokens, to be allocated to real-world assets
     *      that produce income streams and can cover interest payments.
     */
    function withdrawUnderlying(uint underlyingAmount) external returns (bool);

    /**
      * @dev The timestamp at which the exchange rate was last updated.
      */
    function exchangeRateLastUpdatedTimestamp() public view returns (uint);

    /**
     * @dev The exchange rate from underlying to DMM. Invert this number to go from DMM to underlying. This number
     *      has 18 decimals.
     */
    function exchangeRate() external view returns (uint);

    /**
     * @dev The current nonce of the provided `owner`. This `owner` should be the signer for any gasless transactions.
     */
    function nonceOf(address owner) external view returns (uint);

    /**
     * @dev Transfers the token around which this DMMA wraps from msg.sender to the DMMA contract. Then, sends the
     *      corresponding amount of DMM to the msg.sender. Note, this call reverts with INSUFFICIENT_DMM_LIQUIDITY if
     *      there is not enough DMM available to be minted.
     *
     * @return The amount of DMM minted.
     */
    function mintFromUnderlying(uint underlyingAmount) external returns (uint);

    /**
     * @dev Transfers the token around which this DMMA wraps from msg.sender to the DMMA contract. Then, sends the
     *      corresponding amount of DMM to the msg.sender. Note, this call reverts with INSUFFICIENT_DMM_LIQUIDITY if
     *      there is not enough DMM available to be minted.
     *
     * @return The amount of DMM minted.
     */
    function mint(uint amount) external returns (uint);

    /**
     * @dev Transfers the token around which this DMMA wraps from sender to the DMMA contract. Then, sends the
     *      corresponding amount of DMM to recipient. Note, an allowance must be set for sender for the underlying
     *      token that is at least of size `underlyingAmount`. This call reverts with INSUFFICIENT_DMM_LIQUIDITY if
     *      there is not enough DMM available to be minted.
     *
     * @param underlyingAmount  The amount of the underlying token to be pulled and minted into DMM.
     * @param sender            The address that is sending the `underlyingAmount` underlying token.
     * @param recipient         The address the will receive the newly minted DMM.
     * @return The amount of DMM minted.
     */
    function mintFromUnderlyingFrom(uint underlyingAmount, address sender, address recipient) external returns (uint);

    /**
     * @dev Transfers the token around which this DMMA wraps from sender to the DMMA contract. Then, sends the
     *      corresponding amount of DMM to recipient. Note, an allowance must be set for sender for the underlying
     *      token that is at least of size `amount` / `exchangeRate`. This call reverts with INSUFFICIENT_DMM_LIQUIDITY if
     *      there is not enough DMM available to be minted.
     *
     * @param amount        The amount of DMM token to be minted for the recipient.
     * @param sender        The address that is sending the `underlyingAmount` underlying token.
     * @param recipient     The address the will receive the newly minted DMM.
     * @return The amount of underlying pulled from `sender`.
     */
    function mintFrom(uint amount, address sender, address recipient) external returns (uint);

    /**
     * @dev Transfers the token around which this DMMA wraps from sender to the DMMA contract. Then, sends the
     *      corresponding amount of DMM to recipient. Note, an allowance must be set for sender for the underlying
     *      token that is at least of size `amount` / `exchangeRate`. This call reverts with INSUFFICIENT_DMM_LIQUIDITY
     *      if there is not enough DMM available to be minted. See #MINT_TYPE_HASH. This function gives the `owner` the
     *      illusion of committing a gasless transaction, allowing a relayer to broadcast the transaction and
     *      potentially collect a fee for doing so.
     *
     * @param owner         The user that signed the off-chain message.
     * @param recipient     The address that will receive the newly-minted DMM tokens.
     * @param nonce         An auto-incrementing integer that prevents replay attacks. See #nonceOf(address) to get the
     *                      owner's current nonce.
     * @param expiry        The timestamp, in unix seconds, at which the signed off-chain message expires. A value of 0
     *                      means there is no expiration.
     * @param amount        The amount of DMM that should be minted for `owner` and sent to `recipient`.
     * @param feeAmount     The amount of DMM to be sent to feeRecipient for sending this transaction on behalf of
     *                      owner. Can be 0, which means the user won't be charged a fee. Must be <= `amount`.
     * @param feeRecipient  The address that should receive the fee. A value of 0x0 will send the fees to `msg.sender`.
     *                      Note, no fees are sent if the feeAmount is 0, regardless of what feeRecipient is.
     * @param v             The ECDSA V parameter.
     * @param r             The ECDSA R parameter.
     * @param s             The ECDSA S parameter.
     * @return  The amount of DMM minted to recipient.
     */
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
    ) external returns (uint);

    /**
     * @dev Transfers DMM from msg.sender to this DMMA contract. Then, sends the corresponding amount of token around
     *      which this DMMA wraps to the msg.sender. Note, this call reverts with INSUFFICIENT_UNDERLYING_LIQUIDITY if
     *      there is not enough underlying available to be redeemed.
     *
     * @param underlyingAmount  The amount of underlying that should be redeemed and sent to msg.sender from this DMMA.
     * @return                  The amount of DMM that was transferred from msg.sender to this DMMA.
     */
    function redeemFromUnderlying(uint underlyingAmount) external returns (uint);

    /**
     * @dev Transfers DMM from msg.sender to this DMMA contract. Then, sends the corresponding amount of token around
     *      which this DMMA wraps to the msg.sender. Note, this call reverts with INSUFFICIENT_UNDERLYING_LIQUIDITY if
     *      there is not enough DMM available to be redeemed.
     *
     * @param amount    The amount of DMM to be transferred from msg.sender to this DMMA.
     * @return          The amount of underlying redeemed.
     */
    function redeem(uint amount) external returns (uint);

    /**
     * @dev Transfers DMM from `sender` to this DMMA contract. Then, sends the corresponding amount of token around
     *      which this DMMA wraps to `recipient`. Note, an allowance must be set for sender for DMM that is at least of
     *      size `underlyingAmount` * `exchangeRate`. This call reverts with INSUFFICIENT_UNDERLYING_LIQUIDITY if there
     *      is not enough underlying available to be redeemed.
     *
     * @param underlyingAmount  The amount of the underlying token that should be sent to `recipient`.
     * @param sender            The address that is sending the DMM to this DMMA.
     * @param recipient         The address the will receive the newly redeemed underlying token.
     * @return                  The amount of DMM redeemed.
     */
    function redeemFromUnderlyingFrom(uint underlyingAmount, address sender, address recipient) external returns (uint);

    /**
     * @dev Transfers DMM from `sender` to this DMMA contract. Then, sends the corresponding amount of token around
     *      which this DMMA wraps to `recipient`. Note, an allowance must be set for sender for DMM that is at least of
     *      size `amount`. This call reverts with INSUFFICIENT_UNDERLYING_LIQUIDITY if there is not enough underlying
     *      available to be redeemed.
     *
     * @param amount        The amount of DMM token to be redeemed for the recipient.
     * @param sender        The address that is sending the `underlyingAmount` underlying token.
     * @param recipient     The address the will receive the newly redeemed DMM.
     * @return The amount of underlying pulled from `sender`.
     */
    function redeemFrom(uint amount, address sender, address recipient) external returns (uint);

    /**
     * @dev Transfers DMM from `owner` to the DMMA contract. Then, sends the corresponding amount of token around which
     *      this DMMA wraps to `recipient`. Note, an allowance must be set for sender for the underlying
     *      token that is at least of size `amount`. This call reverts with INSUFFICIENT_UNDERLYING_LIQUIDITY
     *      if there is not enough underlying available to be redeemed. See #REDEEM_TYPE_HASH. This function gives the
     *      `owner` the illusion of committing a gasless transaction, allowing a relayer to broadcast the transaction
     *      and potentially collect a fee for doing so.
     *
     * @param owner         The user that signed the off-chain message.
     * @param recipient     The address that will receive the newly-redeemed DMM tokens.
     * @param nonce         An auto-incrementing integer that prevents replay attacks. See #nonceOf(address) to get the
     *                      owner's current nonce.
     * @param expiry        The timestamp, in unix seconds, at which the signed off-chain message expires. A value of 0
     *                      means there is no expiration.
     * @param amount        The amount of DMM that should be redeemed for `owner` and sent to `recipient`.
     * @param feeAmount     The amount of DMM to be sent to feeRecipient for sending this transaction on behalf of
     *                      owner. Can be 0, which means the user won't be charged a fee. Must be <= `amount`
     * @param feeRecipient  The address that should receive the fee. A value of 0x0 will send the fees to `msg.sender`.
     *                      Note, no fees are sent if the feeAmount is 0, regardless of what feeRecipient is.
     * @param v             The ECDSA V parameter.
     * @param r             The ECDSA R parameter.
     * @param s             The ECDSA S parameter.
     * @return  The amount of underlying received by recipient.
     */
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
    ) external returns (uint);

    /**
     * @dev Sets an allowance for owner with spender using an offline-generated signature. This function allows a
     *      relayer to send the transaction, giving the owner the illusion of committing a gasless transaction. See
     *      #PERMIT_TYPEHASH.
     *
     * @param owner         The user that signed the off-chain message.
     * @param spender       The contract/wallet that can spend DMM tokens on behalf of owner.
     * @param nonce         An auto-incrementing integer that prevents replay attacks. See #nonceOf(address) to get the
     *                      owner's current nonce.
     * @param expiry        The timestamp, in unix seconds, at which the signed off-chain message expires. A value of 0
     *                      means there is no expiration.
     * @param allowed       True if the spender can spend funds on behalf of owner or false to revoke this privilege.
     * @param feeAmount     The amount of DMM to be sent to feeRecipient for sending this transaction on behalf of
     *                      owner. Can be 0, which means the user won't be charged a fee.
     * @param feeRecipient  The address that should receive the fee. A value of 0x0 will send the fees to `msg.sender`.
     *                      Note, no fees are sent if the feeAmount is 0, regardless of what feeRecipient is.
     * @param v             The ECDSA V parameter.
     * @param r             The ECDSA R parameter.
     * @param s             The ECDSA S parameter.
     */
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
    ) external;

    /**
     * @dev Transfers DMM from the `owner` to `recipient` using an offline-generated signature. This function allows a
     *      relayer to send the transaction, giving the owner the illusion of committing a gasless transaction. See
     *      #TRANSFER_TYPEHASH. This function gives the `owner` the illusion of committing a gasless transaction,
     *      allowing a relayer to broadcast the transaction and potentially collect a fee for doing so.
     *
     * @param owner         The user that signed the off-chain message and originator of the transfer.
     * @param recipient     The address that will receive the transferred DMM tokens.
     * @param nonce         An auto-incrementing integer that prevents replay attacks. See #nonceOf(address) to get the
     *                      owner's current nonce.
     * @param expiry        The timestamp, in unix seconds, at which the signed off-chain message expires. A value of 0
     *                      means there is no expiration.
     * @param amount        The amount of DMM that should be transferred from `owner` and sent to `recipient`.
     * @param feeAmount     The amount of DMM to be sent to feeRecipient for sending this transaction on behalf of
     *                      owner. Can be 0, which means the user won't be charged a fee.
     * @param feeRecipient  The address that should receive the fee. A value of 0x0 will send the fees to `msg.sender`.
     *                      Note, no fees are sent if the feeAmount is 0, regardless of what feeRecipient is.
     * @param v             The ECDSA V parameter.
     * @param r             The ECDSA R parameter.
     * @param s             The ECDSA S parameter.
     * @return              True if the transfer was successful or false if it failed.
     */
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
    ) external;

}