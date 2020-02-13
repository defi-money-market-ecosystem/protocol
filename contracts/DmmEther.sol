pragma solidity ^0.5.0;

import "./interfaces/IWETH.sol";
import "./DmmToken.sol";

/**
 * @dev A wrapper around Ether and WETH for minting DMM.
 */
contract DmmEther is DmmToken {

    address public wethToken;

    bool private _shouldTransferIn = true;
    bool private _shouldRedeemToETH = true;

    constructor(
        address _wethToken,
        string memory _symbol,
        string memory _name,
        uint8 _decimals,
        uint _minMintAmount,
        uint _minRedeemAmount,
        uint _totalSupply,
        address _controller
    ) public DmmToken(
        _symbol,
        _name,
        _decimals,
        _minMintAmount,
        _minRedeemAmount,
        _totalSupply,
        _controller
    ) {
        wethToken = _wethToken;
    }

    function() payable external {
        // If ETH is sent by the WETH contract, do nothing - this means we're unwrapping
        if (_msgSender() != wethToken) {
            mintViaEther();
        }
    }

    function mintViaEther() whenNotPaused isNotDisabled public payable returns (uint) {
        require(msg.value > 0, "INSUFFICIENT_VALUE");
        IWETH(wethToken).deposit.value(msg.value)();
        _shouldTransferIn = false;

        return _mint(_msgSender(), _msgSender(), msg.value);
    }

    function mintFromViaEther(
        address sender,
        address recipient
    ) whenNotPaused isNotDisabled public payable returns (uint) {
        require(msg.value > 0, "INSUFFICIENT_VALUE");
        IWETH(wethToken).deposit.value(msg.value)();
        _shouldTransferIn = false;

        // Call super because there is authentication done in there.
        return super.mintFrom(sender, recipient, msg.value);
    }

    function mint(
        uint underlyingAmount
    )
    whenNotPaused
    isNotDisabled
    public returns (uint) {
        _shouldTransferIn = true;
        return _mint(_msgSender(), _msgSender(), underlyingAmount);
    }


    function mintFrom(
        address sender,
        address recipient,
        uint underlyingAmount
    )
    whenNotPaused
    isNotDisabled
    public returns (uint) {
        _shouldTransferIn = true;
        // Call super because there is authentication done in there.
        return super.mintFrom(sender, recipient, underlyingAmount);
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
    isNotDisabled
    public returns (uint) {
        _shouldTransferIn = true;
        return mintFromGaslessRequest(
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

    function redeemToWETH(uint amount) whenNotPaused public returns (uint) {
        _shouldRedeemToETH = false;
        return _redeem(_msgSender(), _msgSender(), amount);
    }

    function redeemFromToWETH(
        address sender,
        address recipient,
        uint amount
    ) whenNotPaused public payable returns (uint) {
        _shouldRedeemToETH = false;
        // Call super because there is authentication done in there.
        return super.redeemFrom(sender, recipient, amount);
    }

    function redeem(uint amount) whenNotPaused public returns (uint) {
        _shouldRedeemToETH = true;
        return _redeem(_msgSender(), _msgSender(), amount);
    }

    function redeemFrom(
        address sender,
        address recipient,
        uint amount
    ) whenNotPaused public returns (uint) {
        _shouldRedeemToETH = true;
        // Call super because there is authentication done in there.
        return super.redeemFrom(sender, recipient, amount);
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
        _shouldRedeemToETH = true;
        return super.redeemFromGaslessRequest(
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

    function redeemFromGaslessRequestToWETH(
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
        _shouldRedeemToETH = false;
        return super.redeemFromGaslessRequest(
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

    function transferUnderlyingIn(address sender, uint underlyingAmount) internal {
        if (!_shouldTransferIn) {
            // Do nothing. The ETH was already transferred into this contract
        } else {
            address underlyingToken = controller.getUnderlyingTokenForDmm(address(this));
            IERC20(underlyingToken).safeTransferFrom(sender, address(this), underlyingAmount.sub(msg.value));
        }
    }

    function transferUnderlyingOut(address recipient, uint underlyingAmount) internal {
        address underlyingToken = controller.getUnderlyingTokenForDmm(address(this));
        if (_shouldRedeemToETH) {
            IWETH(underlyingToken).withdraw(underlyingAmount);
            address(uint160(recipient)).send(underlyingAmount);
        } else {
            IERC20(underlyingToken).safeTransfer(recipient, underlyingAmount.sub(msg.value));
        }
    }

}