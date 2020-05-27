/*
 * Copyright 2020 Dolomite
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

pragma solidity ^0.5.0;

import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../protocol/interfaces/IDmmEther.sol";
import "../../protocol/interfaces/IDmmToken.sol";

/**
 * @dev This proxy contract is used for industry partners so we can track their usage of the protocol.
 */
contract ReferralTrackerProxy is Ownable {

    using SafeERC20 for IERC20;

    address public weth;

    event ProxyMint(address indexed minter, address indexed receiver, uint amount, uint underlyingAmount);
    event ProxyRedeem(address indexed redeemer, address indexed receiver, uint amount, uint underlyingAmount);

    constructor (address _weth) public {
        weth = _weth;
    }

    function() external {
        revert("NO_DEFAULT");
    }

    function mintViaEther(address mETH) public payable returns (uint) {
        require(
            IDmmEther(mETH).wethToken() == weth,
            "INVALID_TOKEN"
        );
        uint amount = IDmmEther(mETH).mintViaEther.value(msg.value)();
        IERC20(mETH).safeTransfer(msg.sender, amount);
        emit ProxyMint(msg.sender, msg.sender, amount, msg.value);
        return amount;
    }

    function mint(address mToken, uint underlyingAmount) public {
        address underlyingToken = IDmmToken(mToken).controller().getUnderlyingTokenForDmm(mToken);
        IERC20(underlyingToken).safeTransferFrom(_msgSender(), address(this), underlyingAmount);

        _checkApprovalAndIncrementIfNecessary(underlyingToken, mToken);

        uint amountMinted = IDmmToken(mToken).mint(underlyingAmount);
        IERC20(mToken).safeTransfer(_msgSender(), amountMinted);

        emit ProxyMint(_msgSender(), _msgSender(), amountMinted, underlyingAmount);
    }

    function mintFromGaslessRequest(
        address mToken,
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
    ) external returns (uint) {
        uint dmmAmount = IDmmToken(mToken).mintFromGaslessRequest(
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

        emit ProxyMint(owner, recipient, dmmAmount, amount);
        return dmmAmount;
    }

    function redeem(address mToken, uint amount) public {
        IERC20(mToken).safeTransferFrom(_msgSender(), address(this), amount);

        // We don't need an allowance to perform a redeem using mTokens. Therefore, no allowance check is placed here.
        uint underlyingAmountRedeemed = IDmmToken(mToken).redeem(amount);

        address underlyingToken = IDmmToken(mToken).controller().getUnderlyingTokenForDmm(mToken);
        IERC20(underlyingToken).safeTransfer(_msgSender(), underlyingAmountRedeemed);

        emit ProxyRedeem(_msgSender(), _msgSender(), amount, underlyingAmountRedeemed);
    }

    function redeemFromGaslessRequest(
        address mToken,
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
    ) external returns (uint) {
        uint underlyingAmount = IDmmToken(mToken).redeemFromGaslessRequest(
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

        emit ProxyRedeem(owner, recipient, amount, underlyingAmount);
        return underlyingAmount;
    }

    function _checkApprovalAndIncrementIfNecessary(address token, address mToken) internal {
        uint allowance = IERC20(token).allowance(address(this), mToken);
        if (allowance != uint(- 1)) {
            IERC20(token).safeApprove(mToken, uint(- 1));
        }
    }

}