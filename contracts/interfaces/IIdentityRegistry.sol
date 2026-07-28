// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IIdentityRegistry
 * @notice Answers the question: "is this address a verified investor?"
 *
 * In the real ERC-3643, this is backed by OnchainID identities holding signed
 * claims from trusted issuers. Here we keep a simplified version so you can build
 * the token first, then swap in the real thing later.
 */
interface IIdentityRegistry {
    /// @notice true if `account` is a currently-verified investor eligible to hold the token
    function isVerified(address account) external view returns (bool);

    /// @notice the ISO country code registered for an investor (0 if unknown)
    function investorCountry(address account) external view returns (uint16);
}
