pragma solidity ^0.5.0;

import "./DmmToken.sol";
import "../interfaces/IWETH.sol";

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

        return _mint(_msgSender(), _msgSender(), msg.value, /* shouldDelegateCall */ false);
    }

    function mintFromViaEther(
        address sender,
        address recipient
    ) whenNotPaused isNotDisabled public payable returns (uint) {
        require(msg.value > 0, "INSUFFICIENT_VALUE");
        IWETH(wethToken).deposit.value(msg.value)();
        _shouldTransferIn = false;

        return _mint(sender, recipient, msg.value, /* shouldDelegateCall */ true);
    }

    function mint(
        uint underlyingAmount
    )
    whenNotPaused
    isNotDisabled
    public returns (uint) {
        _shouldTransferIn = true;
        return _mint(_msgSender(), _msgSender(), underlyingAmount, /* shouldDelegateCall */ false);
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
        return _mint(sender, recipient, underlyingAmount, /* shouldDelegateCall */ true);
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
        return super.mintFromGaslessRequest(
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
        return _redeem(_msgSender(), _msgSender(), amount, /* shouldUseAllowance */ false);
    }

    function redeemFromToWETH(
        address sender,
        address recipient,
        uint amount
    ) whenNotPaused public payable returns (uint) {
        _shouldRedeemToETH = false;
        return _redeem(sender, recipient, amount, /* shouldUseAllowance */ true);
    }

    function redeem(uint amount) whenNotPaused public returns (uint) {
        _shouldRedeemToETH = true;
        return _redeem(_msgSender(), _msgSender(), amount, /* shouldUseAllowance */ false);
    }

    function redeemFrom(
        address sender,
        address recipient,
        uint amount
    ) whenNotPaused public returns (uint) {
        _shouldRedeemToETH = true;
        return _redeem(sender, recipient, amount, /* shouldUseAllowance */ true);
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

    function transferUnderlyingIn(address sender, uint underlyingAmount, bool shouldDelegateCall) internal {
        if (!_shouldTransferIn) {
            // Do nothing. The ETH was already transferred into this contract
        } else {
            super.transferUnderlyingIn(sender, underlyingAmount, shouldDelegateCall);
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