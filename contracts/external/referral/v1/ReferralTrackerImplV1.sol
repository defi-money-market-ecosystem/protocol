/*
 * Copyright 2020 DMM Foundation
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

import "../../../../node_modules/@openzeppelin/upgrades/contracts/Initializable.sol";

import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../../protocol/interfaces/IDmmEther.sol";
import "../../../protocol/interfaces/IDmmToken.sol";
import "../../../protocol/interfaces/IWETH.sol";

import "../ReferralTrackerData.sol";

import "./IReferralTrackerV1.sol";
import "./IReferralTrackerV1Initializable.sol";

/**
 * @dev This proxy contract is used for industry partners so we can track their usage of the protocol.
 */
contract ReferralTrackerImplV1 is IReferralTrackerV1, IReferralTrackerV1Initializable, ReferralTrackerData {

    using SafeERC20 for IERC20;

    function initialize(
        address __owner,
        address __weth
    ) external initializer {
        _transferOwnership(__owner);
        _weth = __weth;
    }

    function() external payable {
        require(
            msg.sender == _weth,
            "ReferralTrackerProxy::default INVALID_SENDER"
        );
    }

    function weth() external view returns (address) {
        return _weth;
    }

    function mintViaEther(
        address __referrer,
        address __mETH
    ) public payable returns (uint) {
        require(
            IDmmEther(__mETH).wethToken() == _weth,
            "ReferralTrackerProxy::mintViaEther: INVALID_TOKEN"
        );

        uint amount = IDmmEther(__mETH).mintViaEther.value(msg.value)();
        IERC20(__mETH).safeTransfer(msg.sender, amount);
        emit ProxyMint(__referrer, msg.sender, msg.sender, amount, msg.value);
        return amount;
    }

    function mint(
        address __referrer,
        address __mToken,
        uint __underlyingAmount
    ) external returns (uint) {
        address underlyingToken = IDmmToken(__mToken).controller().getUnderlyingTokenForDmm(__mToken);
        IERC20(underlyingToken).safeTransferFrom(msg.sender, address(this), __underlyingAmount);

        _checkApprovalAndIncrementIfNecessary(underlyingToken, __mToken);

        uint amountMinted = IDmmToken(__mToken).mint(__underlyingAmount);
        IERC20(__mToken).safeTransfer(msg.sender, amountMinted);

        emit ProxyMint(__referrer, msg.sender, msg.sender, amountMinted, __underlyingAmount);

        return amountMinted;
    }

    function mintFromGaslessRequest(
        address __referrer,
        address __mToken,
        address __owner,
        address __recipient,
        uint __nonce,
        uint __expiry,
        uint __amount,
        uint __feeAmount,
        address __feeRecipient,
        uint8 __v,
        bytes32 __r,
        bytes32 __s
    ) external returns (uint) {
        uint dmmAmount = IDmmToken(__mToken).mintFromGaslessRequest(
            __owner,
            __recipient,
            __nonce,
            __expiry,
            __amount,
            __feeAmount,
            __feeRecipient,
            __v,
            __r,
            __s
        );

        emit ProxyMint(__referrer, __owner, __recipient, dmmAmount, __amount);
        return dmmAmount;
    }

    function redeem(
        address __referrer,
        address __mToken,
        uint __amount
    ) external returns (uint) {
        IERC20(__mToken).safeTransferFrom(msg.sender, address(this), __amount);

        // We don't need an allowance to perform a redeem using mTokens. Therefore, no allowance check is placed here.
        uint underlyingAmountRedeemed = IDmmToken(__mToken).redeem(__amount);

        address underlyingToken = IDmmToken(__mToken).controller().getUnderlyingTokenForDmm(__mToken);
        IERC20(underlyingToken).safeTransfer(msg.sender, underlyingAmountRedeemed);

        emit ProxyRedeem(__referrer, msg.sender, msg.sender, __amount, underlyingAmountRedeemed);

        return underlyingAmountRedeemed;
    }

    function redeemToEther(
        address __referrer,
        address __mToken,
        uint __amount
    ) external returns (uint) {
        require(
            IDmmEther(__mToken).wethToken() == _weth,
            "ReferralTrackerProxy::redeemToEther: INVALID_TOKEN"
        );

        IERC20(__mToken).safeTransferFrom(msg.sender, address(this), __amount);

        // We don't need an allowance to perform a redeem using mTokens. Therefore, no allowance check is placed here.
        uint underlyingAmountRedeemed = IDmmToken(__mToken).redeem(__amount);

        IWETH(_weth).withdraw(underlyingAmountRedeemed);
        Address.sendValue(msg.sender, underlyingAmountRedeemed);

        emit ProxyRedeem(__referrer, msg.sender, msg.sender, __amount, underlyingAmountRedeemed);

        return underlyingAmountRedeemed;
    }

    function redeemFromGaslessRequest(
        address __referrer,
        address __mToken,
        address __owner,
        address __recipient,
        uint __nonce,
        uint __expiry,
        uint __amount,
        uint __feeAmount,
        address __feeRecipient,
        uint8 __v,
        bytes32 __r,
        bytes32 __s
    ) external returns (uint) {
        uint underlyingAmount = IDmmToken(__mToken).redeemFromGaslessRequest(
            __owner,
            __recipient,
            __nonce,
            __expiry,
            __amount,
            __feeAmount,
            __feeRecipient,
            __v,
            __r,
            __s
        );

        emit ProxyRedeem(__referrer, __owner, __recipient, __amount, underlyingAmount);
        return underlyingAmount;
    }

    // ******************************
    // ***** Internal Functions
    // ******************************

    function _checkApprovalAndIncrementIfNecessary(
        address __underlyingToken,
        address __mToken
    ) internal {
        uint allowance = IERC20(__underlyingToken).allowance(address(this), __mToken);
        if (allowance == 0) {
            IERC20(__underlyingToken).safeApprove(__mToken, uint(- 1));
        }
    }

}