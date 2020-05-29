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

import "../../../node_modules/@openzeppelin/contracts/math/SafeMath.sol";
import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract DMGTokenForwarder is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Released(address indexed to, uint256 amount);
    event BeneficiaryChanged(address indexed oldBeneficiary, address indexed newBeneficiary);

    address public beneficiary;

    mapping(address => uint256) public tokenToReleasedAmountMap;

    modifier onlyBeneficiary {
        require(beneficiary == msg.sender, "DMGTokenForwarder: INVALID_BENEFICIARY");
        _;
    }

    /**
     * @dev Creates a forwarding contract that vests its balance of any ERC20 token from the
     * _beneficiary.
     * @param _beneficiary address of the beneficiary from whom vested tokens are transferred
     */
    constructor(
        address _beneficiary
    )
    public
    {
        require(_beneficiary != address(0));
        beneficiary = _beneficiary;
    }

    function setBeneficiary(address _beneficiary) public onlyBeneficiary {
        address oldBeneficiary = beneficiary;
        beneficiary = _beneficiary;
        emit BeneficiaryChanged(oldBeneficiary, _beneficiary);
    }

    /**
     * @notice Transfers vested tokens from this contract to the recipient.
     * @param _token ERC20 token which is being vested
     */
    function release(address _to, address _token, uint _amount) public onlyBeneficiary {
        require(
            IERC20(_token).balanceOf(address(this)) >= _amount,
            "DMGTokenForwarder: INSUFFICIENT_BALANCE"
        );
        tokenToReleasedAmountMap[_token] = tokenToReleasedAmountMap[_token].add(_amount);
        IERC20(_token).safeTransfer(_to, _amount);
        emit Released(_to, _amount);
    }
}