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

    function mintViaEther()
    whenNotPaused
    nonReentrant
    isNotDisabled
    public payable returns (uint) {
        require(msg.value > 0, "INSUFFICIENT_VALUE");
        IWETH(wethToken).deposit.value(msg.value)();
        _shouldTransferIn = false;

        return _mint(_msgSender(), _msgSender(), msg.value);
    }

    function mint(
        uint underlyingAmount
    )
    whenNotPaused
    nonReentrant
    isNotDisabled
    public returns (uint) {
        _shouldTransferIn = true;
        return _mint(_msgSender(), _msgSender(), underlyingAmount);
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
        _shouldTransferIn = true;
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

    function redeemToWETH(
        uint amount
    )
    whenNotPaused
    nonReentrant
    public returns (uint) {
        _shouldRedeemToETH = false;
        return _redeem(_msgSender(), _msgSender(), amount, /* shouldUseAllowance */ false);
    }

    function redeem(
        uint amount
    )
    whenNotPaused
    nonReentrant
    public returns (uint) {
        _shouldRedeemToETH = true;
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
        _shouldRedeemToETH = true;
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

    function transferUnderlyingIn(address sender, uint underlyingAmount) internal {
        if (!_shouldTransferIn) {
            // Do nothing. The ETH was already transferred into this contract
        } else {
            super.transferUnderlyingIn(sender, underlyingAmount);
        }
    }

    function transferUnderlyingOut(address recipient, uint underlyingAmount) internal {
        address underlyingToken = controller.getUnderlyingTokenForDmm(address(this));
        if (_shouldRedeemToETH) {
            IWETH(underlyingToken).withdraw(underlyingAmount);
            (bool success,) = address(uint160(recipient)).call.value(underlyingAmount)("");
            require(success, "COULD_NOT_TRANSFER_ETH_OUT");
        } else {
            IERC20(underlyingToken).safeTransfer(recipient, underlyingAmount.sub(msg.value));
        }
    }

}