// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ICompliance} from "./interfaces/ICompliance.sol";

/**
 * @title ModularCompliance
 * @notice Holds the transfer RULES, separate from investor identity.
 *
 * This starter implements one real rule — a maximum holder count — plus the
 * bookkeeping needed to enforce it (tracking how many holders currently hold a
 * non-zero balance). It's structured so you can add more rule modules later
 * (per-country caps, lockup periods, max balance per investor) without touching
 * the token.
 *
 * Only the bound token may call the state-changing hooks, so its holder counter
 * can't be corrupted by outside callers.
 */
contract ModularCompliance is ICompliance, AccessControl {
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    address public token;
    uint256 public maxHolders;      // 0 == unlimited
    uint256 public holderCount;

    // balance mirror so we know when someone crosses 0 -> positive or positive -> 0
    mapping(address => uint256) private _bal;

    event TokenBound(address indexed token);
    event MaxHoldersSet(uint256 maxHolders);

    error OnlyToken();
    error ZeroAddress();

    modifier onlyToken() {
        if (msg.sender != token) revert OnlyToken();
        _;
    }

    constructor(address owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
        _grantRole(OWNER_ROLE, owner_);
    }

    function bindToken(address token_) external onlyRole(OWNER_ROLE) {
        if (token_ == address(0)) revert ZeroAddress();
        token = token_;
        emit TokenBound(token_);
    }

    function setMaxHolders(uint256 maxHolders_) external onlyRole(OWNER_ROLE) {
        maxHolders = maxHolders_;
        emit MaxHoldersSet(maxHolders_);
    }

    // ---- ICompliance: the read-only rule check ----

    function canTransfer(address, address to, uint256 amount)
        external
        view
        returns (bool)
    {
        if (amount == 0) return true;
        // if `to` is a new holder and we're at the cap, block it
        if (maxHolders != 0 && _bal[to] == 0 && holderCount >= maxHolders) {
            return false;
        }
        return true;
    }

    // ---- ICompliance: state-updating hooks, token-only ----

    function transferred(address from, address to, uint256 amount) external onlyToken {
        _decrease(from, amount);
        _increase(to, amount);
    }

    function created(address to, uint256 amount) external onlyToken {
        _increase(to, amount);
    }

    function destroyed(address from, uint256 amount) external onlyToken {
        _decrease(from, amount);
    }

    // ---- internal holder bookkeeping ----

    function _increase(address who, uint256 amount) private {
        uint256 prev = _bal[who];
        if (prev == 0 && amount > 0) holderCount += 1;
        _bal[who] = prev + amount;
    }

    function _decrease(address who, uint256 amount) private {
        uint256 prev = _bal[who];
        uint256 next = prev - amount; // underflow-safe: token already moved the balance
        if (prev > 0 && next == 0) holderCount -= 1;
        _bal[who] = next;
    }

    function trackedBalance(address who) external view returns (uint256) {
        return _bal[who];
    }
}
