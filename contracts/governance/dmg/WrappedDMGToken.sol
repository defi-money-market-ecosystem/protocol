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
import "../../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./DMGToken.sol";
import "./WrappedDmgTokenData.sol";
import "./DMGTokenConstants.sol";

/**
 * A wrapped variant of DMG that is used by a minter to allow users to receive voting representation while otherwise
 * locking up their underlying DMG tokens. Useful for things like staking, pooling contracts, and other forms of
 * aggregation.
 */
contract WrappedDMGToken is IDMGToken, IERC20, DMGTokenConstants, WrappedDmgTokenData {

    string public constant name = "Wrapped DMM: Governance V2";

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    modifier onlyMinter() {
        require(
            _minterMap[msg.sender],
            "WrappedDMGToken: NOT_MINTER"
        );

        _;
    }

    function initialize(
        address _owner,
        address _dmg,
        address _account,
        uint _totalSupply
    )
    public
    initializer {
        require(
            _totalSupply == uint128(_totalSupply),
            "WrappedDMGToken::initialize: total supply exceeds 128 bits"
        );

        owner = _owner;
        totalSupply = _totalSupply;

        domainSeparator = keccak256(
            abi.encode(DOMAIN_TYPE_HASH, keccak256(bytes(name)), EvmUtil.getChainId(), address(this))
        );

        if (_totalSupply > 0) {
            balances[_account] = uint128(_totalSupply);
            emit Transfer(address(0), _account, _totalSupply);
        }

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
        emit MinterAdded(minter);
    }

    function removeMinter(
        address minter
    )
    onlyOwner
    public {
        _minterMap[minter] = false;
        emit MinterRemoved(minter);
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

    /**
     * @notice Get the number of tokens `spender` is approved to spend on behalf of `account`
     * @param account The address of the account holding the funds
     * @param spender The address of the account spending the funds
     * @return The number of tokens approved
     */
    function allowance(address account, address spender) external view returns (uint) {
        return allowances[account][spender];
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param rawAmount The number of tokens that are approved (2^256-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint rawAmount) external returns (bool) {
        uint128 amount;
        if (rawAmount == uint(- 1)) {
            amount = uint128(- 1);
        } else {
            amount = SafeBitMath.safe128(rawAmount, "WrappedDMGToken::approve: amount exceeds 128 bits");
        }

        _approveTokens(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Get the number of tokens held by the `account`
     * @param account The address of the account to get the balance of
     * @return The number of tokens held
     */
    function balanceOf(address account) external view returns (uint) {
        return balances[account];
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param rawAmount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address dst, uint rawAmount) external returns (bool) {
        uint128 amount = SafeBitMath.safe128(rawAmount, "WrappedDMGToken::transfer: amount exceeds 128 bits");
        _transferTokens(msg.sender, dst, amount);
        return true;
    }

    /**
     * @notice Transfers `amount` tokens from `msg.sender` to the zero address
     * @param rawAmount The number of tokens to burn
     * @return Whether or not the transfer succeeded
    */
    function burn(uint rawAmount) external returns (bool) {
        uint128 amount = SafeBitMath.safe128(rawAmount, "WrappedDMGToken::burn: amount exceeds 128 bits");
        _burnTokens(msg.sender, amount);
        return true;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param rawAmount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address src, address dst, uint rawAmount) external returns (bool) {
        address spender = msg.sender;
        uint128 spenderAllowance = allowances[src][spender];
        uint128 amount = SafeBitMath.safe128(rawAmount, "WrappedDMGToken::allowances: amount exceeds 128 bits");

        if (spender != src && spenderAllowance != uint128(- 1)) {
            uint128 newAllowance = SafeBitMath.sub128(spenderAllowance, amount, "WrappedDMGToken::transferFrom: transfer amount exceeds spender allowance");
            allowances[src][spender] = newAllowance;

            emit Approval(src, spender, newAllowance);
        }

        _transferTokens(src, dst, amount);
        return true;
    }

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegatee The address to delegate votes to
     */
    function delegate(address delegatee) public {
        return _delegate(msg.sender, delegatee);
    }

    function nonceOf(address signer) public view returns (uint) {
        return nonces[signer];
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPE_HASH, delegatee, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "WrappedDMGToken::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "WrappedDMGToken::delegateBySig: invalid nonce");
        require(now <= expiry, "WrappedDMGToken::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Transfers tokens from signatory to `recipient`
     * @param recipient The address to receive the tokens
     * @param rawAmount The amount of tokens to be sent to recipient
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function transferBySig(address recipient, uint rawAmount, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 structHash = keccak256(abi.encode(TRANSFER_TYPE_HASH, recipient, rawAmount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "WrappedDMGToken::transferBySig: invalid signature");
        require(nonce == nonces[signatory]++, "WrappedDMGToken::transferBySig: invalid nonce");
        require(now <= expiry, "WrappedDMGToken::transferBySig: signature expired");

        uint128 amount = SafeBitMath.safe128(rawAmount, "WrappedDMGToken::transferBySig: amount exceeds 128 bits");
        return _transferTokens(signatory, recipient, amount);
    }

    /**
     * @notice Approves tokens from signatory to be spent by `spender`
     * @param spender The address to receive the tokens
     * @param rawAmount The amount of tokens to be sent to spender
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function approveBySig(address spender, uint rawAmount, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 structHash = keccak256(abi.encode(APPROVE_TYPE_HASH, spender, rawAmount, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "WrappedDMGToken::approveBySig: invalid signature");
        require(nonce == nonces[signatory]++, "WrappedDMGToken::approveBySig: invalid nonce");
        require(now <= expiry, "WrappedDMGToken::approveBySig: signature expired");

        uint128 amount;
        if (rawAmount == uint(- 1)) {
            amount = uint128(- 1);
        } else {
            amount = SafeBitMath.safe128(rawAmount, "WrappedDMGToken::approveBySig: amount exceeds 128 bits");
        }
        _approveTokens(signatory, spender, amount);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account) external view returns (uint128) {
        uint64 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber) public view returns (uint128) {
        require(blockNumber < block.number, "WrappedDMGToken::getPriorVotes: not yet determined");

        uint64 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint64 lower = 0;
        uint64 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint64 center = upper - (upper - lower) / 2;
            // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegates[delegator];
        uint128 delegatorBalance = balances[delegator];
        delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _transferTokens(address src, address dst, uint128 amount) internal {
        require(src != address(0), "WrappedDMGToken::_transferTokens: cannot transfer from the zero address");
        require(dst != address(0), "WrappedDMGToken::_transferTokens: cannot transfer to the zero address");

        balances[src] = SafeBitMath.sub128(balances[src], amount, "WrappedDMGToken::_transferTokens: transfer amount exceeds balance");
        balances[dst] = SafeBitMath.add128(balances[dst], amount, "WrappedDMGToken::_transferTokens: transfer amount overflows");
        emit Transfer(src, dst, amount);

        _moveDelegates(delegates[src], delegates[dst], amount);
    }

    function _approveTokens(address owner, address spender, uint128 amount) internal {
        allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    function _burnTokens(address src, uint128 amount) internal {
        require(src != address(0), "WrappedDMGToken::_burnTokens: cannot burn from the zero address");

        balances[src] = SafeBitMath.sub128(balances[src], amount, "WrappedDMGToken::_burnTokens: burn amount exceeds balance");
        emit Transfer(src, address(0), amount);

        totalSupply = SafeBitMath.sub128(uint128(totalSupply), amount, "WrappedDMGToken::_burnTokens: burn amount exceeds total supply");

        _moveDelegates(delegates[src], address(0), amount);
    }

    function _moveDelegates(address srcRep, address dstRep, uint128 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                uint64 srcRepNum = numCheckpoints[srcRep];
                uint128 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint128 srcRepNew = SafeBitMath.sub128(srcRepOld, amount, "WrappedDMGToken::_moveVotes: vote amount underflows");
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint64 dstRepNum = numCheckpoints[dstRep];
                uint128 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint128 dstRepNew = SafeBitMath.add128(dstRepOld, amount, "WrappedDMGToken::_moveVotes: vote amount overflows");
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(address delegatee, uint64 nCheckpoints, uint128 oldVotes, uint128 newVotes) internal {
        uint64 blockNumber = SafeBitMath.safe64(block.number, "WrappedDMGToken::_writeCheckpoint: block number exceeds 64 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

}