pragma solidity ^0.5.0;

import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../protocol/interfaces/IDmmToken.sol";

/**
 * @dev This proxy contract is used for industry partners so we can track their usage of the protocol.
 */
contract ReferralTrackerProxy is Ownable {

    using SafeERC20 for IERC20;

    event ProxyMint(address indexed minter, uint amount, uint underlyingAmount);
    event ProxyRedeem(address indexed redeemer, uint amount, uint underlyingAmount);

    constructor () public {
    }

    function() external {
        revert("NO_DEFAULT");
    }

    function mint(address mToken, uint underlyingAmount) public {
        address underlyingToken = IDmmToken(mToken).controller().getUnderlyingTokenForDmm(mToken);
        IERC20(underlyingToken).safeTransferFrom(_msgSender(), address(this), underlyingAmount);

        checkApprovalAndIncrementIfNecessary(underlyingToken, mToken);

        uint amountMinted = IDmmToken(mToken).mint(underlyingAmount);
        IERC20(mToken).safeTransfer(_msgSender(), amountMinted);

        emit ProxyMint(_msgSender(), amountMinted, underlyingAmount);
    }

    function redeem(address mToken, uint amount) public {
        IERC20(mToken).safeTransferFrom(_msgSender(), address(this), amount);

        // We don't need an allowance to perform a redeem using mTokens. Therefore, no allowance check is placed here.
        uint underlyingAmountRedeemed = IDmmToken(mToken).redeem(amount);

        address underlyingToken = IDmmToken(mToken).controller().getUnderlyingTokenForDmm(mToken);
        IERC20(underlyingToken).safeTransfer(_msgSender(), underlyingAmountRedeemed);

        emit ProxyRedeem(_msgSender(), amount, underlyingAmountRedeemed);
    }

    function checkApprovalAndIncrementIfNecessary(address token, address mToken) private {
        uint allowance = IERC20(token).allowance(address(this), mToken);
        if (allowance != uint(- 1)) {
            IERC20(token).safeApprove(mToken, uint(- 1));
        }
    }

}