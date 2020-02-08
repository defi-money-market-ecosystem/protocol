pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "../constants/DmmErrorCodes.sol";

/**
 * @dev Allows accounts to be blacklisted by the owner of the contract.
 *
 *  Taken from USDC's contract for blacklisting certain addresses from owning the token.
 */
contract Blacklistable is Ownable, DmmErrorCodes {

    address public blacklister;
    mapping(address => bool) internal blacklisted;

    event Blacklisted(address indexed account);
    event UnBlacklisted(address indexed account);
    event BlacklisterChanged(address indexed newBlacklister);

    /**
     * @dev Throws if called by any account other than the blacklister
    */
    modifier onlyBlacklister() {
        require(msg.sender == blacklister, MUST_BE_BLACKLISTER);
        _;
    }

    /**
     * @dev Throws if `account` is blacklisted
     *
     * @param account The address to check
    */
    modifier notBlacklisted(address account) {
        require(blacklisted[account] == false, BLACKLISTED);
        _;
    }

    /**
     * @dev Checks if `account` is blacklisted. Reverts with `BLACKLISTED` if blacklisted.
    */
    function checkNotBlacklisted(address account) public view {
        require(!blacklisted[account], BLACKLISTED);
    }

    /**
     * @dev Checks if `account` is blacklisted
     *
     * @param account The address to check
    */
    function isBlacklisted(address account) public view returns (bool) {
        return blacklisted[account];
    }

    /**
     * @dev Adds `account` to blacklist
     *
     * @param account The address to blacklist
    */
    function blacklist(address account) public onlyBlacklister {
        blacklisted[account] = true;
        emit Blacklisted(account);
    }

    /**
     * @dev Removes account from blacklist
     *
     * @param account The address to remove from the blacklist
    */
    function unBlacklist(address account) public onlyBlacklister {
        blacklisted[account] = false;
        emit UnBlacklisted(account);
    }

    function updateBlacklister(address _newBlacklister) public onlyOwner {
        require(_newBlacklister != address(0), INVALID_BLACKLISTER);
        blacklister = _newBlacklister;
        emit BlacklisterChanged(blacklister);
    }

}