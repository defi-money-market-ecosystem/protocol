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


pragma solidity ^0.5.13;
pragma experimental ABIEncoderV2;

import "../../../node_modules/@openzeppelin/contracts/ownership/Ownable.sol";

import "./DMGToken.sol";

/**
 * A wrapped variant of DMG that is used by a minter to allow users to receive voting representation while otherwise
 * locking up their underlying DMG tokens. Useful for things like staking, pooling contracts, and other forms of
 * aggregation.
 */
contract WrappedDMGToken is DMGToken, Ownable {

    modifier onlyMinter() {
        require(
            _minterMap[msg.sender],
            "WrappedDMGToken: NOT_MINTER"
        );

        _;
    }

    mapping(address => bool) internal _minterMap;
    IDMGToken public dmg;

    constructor(
        address _dmg,
        address _account,
        uint _totalSupply
    ) public DMGToken(_account, _totalSupply) {
        dmg = IDMGToken(_dmg);
    }

    function isMinter(
        address minter
    )
    public view returns (bool) {
        return _minterMap[minter];
    }

    function addMinter(
        address minter
    )
    onlyOwner
    public {
        _minterMap[minter] = true;
    }

    function removeMinter(
        address minter
    )
    onlyOwner
    public {
        _minterMap[minter] = false;
    }

    function mint(
        address receiver,
        uint rawAmount
    )
    onlyMinter
    public {
        address wDmgDelegatee = delegates[receiver];
        address dmgDelegatee = dmg.delegates(receiver);
        if (wDmgDelegatee == address(0) && dmgDelegatee == address(0)) {
            _delegate(receiver, receiver);
        } else if (wDmgDelegatee == address(0) && dmgDelegatee != address(0)) {
            _delegate(receiver, dmgDelegatee);
        }

        uint128 amount = SafeBitMath.safe128(rawAmount, "WrappedDMGToken::mint: amount exceeds 128 bits");
        _mintTokens(receiver, amount);
    }

    function burn(
        address sender,
        uint rawAmount
    )
    onlyMinter
    public {
        uint128 amount = SafeBitMath.safe128(rawAmount, "WrappedDMGToken::burn: amount exceeds 128 bits");
        _burnTokens(sender, amount);
    }

    function _mintTokens(
        address recipient,
        uint128 amount
    ) internal {
        require(recipient != address(0), "WrappedDMGToken::_mintTokens: cannot mint to the zero address");

        balances[recipient] = SafeBitMath.add128(balances[recipient], amount, "WrappedDMGToken::_mintTokens: balance overflows");
        emit Transfer(address(0), recipient, amount);

        totalSupply = SafeBitMath.add128(uint128(totalSupply), amount, "WrappedDMGToken::_mintTokens: total supply overflows");

        _moveDelegates(address(0), delegates[recipient], amount);
    }

}