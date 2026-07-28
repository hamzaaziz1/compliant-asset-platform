// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";
import {ICompliance} from "./interfaces/ICompliance.sol";

/**
 * @title ComplianceToken
 * @notice A simplified ERC-3643-style permissioned security token.
 *
 * This is a LEARNING implementation that mirrors the real T-REX architecture:
 * the token asks two external contracts for permission before every transfer.
 *   - IdentityRegistry: "is the receiver a verified investor?"
 *   - Compliance:       "does this transfer break any rules?"
 *
 * The design deliberately separates these concerns. Identity changes when an
 * investor's KYC status changes; compliance changes when the RULES change. They
 * live in different contracts so each can be updated without touching the other.
 *
 * NOTE: This is not audited and not production code. It exists to demonstrate and
 * teach the compliance-gated transfer pattern that regulated tokenization relies on.
 */
contract ComplianceToken is ERC20, AccessControl {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    IIdentityRegistry public identityRegistry;
    ICompliance public compliance;

    /// @notice frozen accounts can neither send nor receive via normal transfers
    mapping(address => bool) public frozen;

    // ---- Events ----
    event AssetIssued(address indexed to, uint256 amount);
    event AccountFrozen(address indexed account);
    event AccountUnfrozen(address indexed account);
    event ForcedTransfer(address indexed from, address indexed to, uint256 amount, string reason);
    event IdentityRegistrySet(address indexed registry);
    event ComplianceSet(address indexed compliance);

    // ---- Errors (cheaper than require strings, and clearer to test against) ----
    error ReceiverNotVerified(address account);
    error TransferNotCompliant(address from, address to, uint256 amount);
    error AccountIsFrozen(address account);
    error ZeroAddress();

    constructor(
        string memory name_,
        string memory symbol_,
        address registry_,
        address compliance_,
        address admin_
    ) ERC20(name_, symbol_) {
        if (registry_ == address(0) || compliance_ == address(0) || admin_ == address(0)) {
            revert ZeroAddress();
        }
        identityRegistry = IIdentityRegistry(registry_);
        compliance = ICompliance(compliance_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(AGENT_ROLE, admin_);
    }

    // ---- Admin config ----

    function setIdentityRegistry(address registry_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (registry_ == address(0)) revert ZeroAddress();
        identityRegistry = IIdentityRegistry(registry_);
        emit IdentityRegistrySet(registry_);
    }

    function setCompliance(address compliance_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (compliance_ == address(0)) revert ZeroAddress();
        compliance = ICompliance(compliance_);
        emit ComplianceSet(compliance_);
    }

    // ---- Issuance ----

    /// @notice Mint new tokens to a verified investor. Agent-only.
    function issue(address to, uint256 amount) external onlyRole(AGENT_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        // Even issuance must go to a verified investor.
        if (!identityRegistry.isVerified(to)) revert ReceiverNotVerified(to);
        _mint(to, amount);
        emit AssetIssued(to, amount);
    }

    // ---- Compliance controls ----

    function freeze(address account) external onlyRole(AGENT_ROLE) {
        frozen[account] = true;
        emit AccountFrozen(account);
    }

    function unfreeze(address account) external onlyRole(AGENT_ROLE) {
        frozen[account] = false;
        emit AccountUnfrozen(account);
    }

    /**
     * @notice Move tokens regardless of freeze/compliance state. Agent-only.
     * @dev This is a REQUIRED feature for regulated assets, not a backdoor:
     *      court orders, sanctions enforcement, and estate settlement can all
     *      legally require moving tokens without the holder's consent. The
     *      `reason` string exists so every such action is auditable on-chain.
     */
    function forcedTransfer(address from, address to, uint256 amount, string calldata reason)
        external
        onlyRole(AGENT_ROLE)
    {
        if (to == address(0)) revert ZeroAddress();
        // Forced transfers still require the receiver to be a verified investor —
        // you can seize an asset but you can't park it with an unverified party.
        if (!identityRegistry.isVerified(to)) revert ReceiverNotVerified(to);
        _forced = true;
        _transfer(from, to, amount);
        _forced = false;
        emit ForcedTransfer(from, to, amount, reason);
    }

    // transient flag: true only during a forcedTransfer, so the hook below skips checks
    bool private _forced;

    // ---- The compliance hook: this is the heart of the token ----

    /**
     * @dev OpenZeppelin v5 routes mint, burn, and transfer through _update.
     *      We intercept here and enforce compliance on normal transfers.
     *      - mint (from == 0) and burn (to == 0) skip receiver/compliance checks
     *        (issuance is gated separately in `issue`).
     *      - forcedTransfer sets _forced so legal recovery can bypass restrictions.
     */
    function _update(address from, address to, uint256 value) internal override {
        bool isMint = from == address(0);
        bool isBurn = to == address(0);

        if (!_forced && !isMint && !isBurn) {
            if (frozen[from]) revert AccountIsFrozen(from);
            if (frozen[to]) revert AccountIsFrozen(to);
            if (!identityRegistry.isVerified(to)) revert ReceiverNotVerified(to);
            if (!compliance.canTransfer(from, to, value)) {
                revert TransferNotCompliant(from, to, value);
            }
        }

        super._update(from, to, value);

        // let compliance update its internal counters (holder counts, etc.)
        if (!isMint && !isBurn) {
            compliance.transferred(from, to, value);
        } else if (isMint) {
            compliance.created(to, value);
        } else if (isBurn) {
            compliance.destroyed(from, value);
        }
    }
}
