// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IIdentityRegistry} from "./interfaces/IIdentityRegistry.sol";

/**
 * @title IdentityRegistry
 * @notice Simplified investor registry. In production this is driven off-chain by
 *         a KYC/AML process (see Phase 2) and mirrors the verified set on-chain.
 *
 * Real ERC-3643 stores an OnchainID identity per investor and checks signed claims.
 * We store a boolean + country here so the token can be built and tested now; the
 * interface is deliberately the same shape so the real registry can slot in later.
 */
contract IdentityRegistry is IIdentityRegistry, AccessControl {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    struct Investor {
        bool verified;
        uint16 country; // ISO 3166-1 numeric
    }

    mapping(address => Investor) private _investors;

    event InvestorRegistered(address indexed account, uint16 country);
    event InvestorRemoved(address indexed account);
    event InvestorCountryUpdated(address indexed account, uint16 country);

    error ZeroAddress();

    constructor(address admin_) {
        if (admin_ == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(AGENT_ROLE, admin_);
    }

    function registerInvestor(address account, uint16 country) external onlyRole(AGENT_ROLE) {
        if (account == address(0)) revert ZeroAddress();
        _investors[account] = Investor({verified: true, country: country});
        emit InvestorRegistered(account, country);
    }

    function removeInvestor(address account) external onlyRole(AGENT_ROLE) {
        delete _investors[account];
        emit InvestorRemoved(account);
    }

    function updateCountry(address account, uint16 country) external onlyRole(AGENT_ROLE) {
        require(_investors[account].verified, "not registered");
        _investors[account].country = country;
        emit InvestorCountryUpdated(account, country);
    }

    function isVerified(address account) external view returns (bool) {
        return _investors[account].verified;
    }

    function investorCountry(address account) external view returns (uint16) {
        return _investors[account].country;
    }
}
