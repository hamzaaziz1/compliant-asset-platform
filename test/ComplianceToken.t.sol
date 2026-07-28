// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ComplianceToken} from "../contracts/ComplianceToken.sol";
import {IdentityRegistry} from "../contracts/IdentityRegistry.sol";
import {ModularCompliance} from "../contracts/ModularCompliance.sol";

/**
 * These tests exist to prove the NEGATIVE cases — that compliance can't be
 * bypassed. The happy path is easy; the value is in proving the rules hold.
 */
contract ComplianceTokenTest is Test {
    ComplianceToken token;
    IdentityRegistry registry;
    ModularCompliance compliance;

    address admin = makeAddr("admin");
    address alice = makeAddr("alice"); // verified
    address bob   = makeAddr("bob");   // verified
    address mallory = makeAddr("mallory"); // NOT verified

    uint16 constant UK = 826;
    uint16 constant UAE = 784;

    function setUp() public {
        vm.startPrank(admin);
        registry = new IdentityRegistry(admin);
        compliance = new ModularCompliance(admin);
        token = new ComplianceToken("Private Credit Note", "PCN", address(registry), address(compliance), admin);
        compliance.bindToken(address(token));

        registry.registerInvestor(alice, UK);
        registry.registerInvestor(bob, UAE);
        vm.stopPrank();
    }

    // ---- issuance ----

    function test_issue_toVerifiedInvestor_succeeds() public {
        vm.prank(admin);
        token.issue(alice, 1_000e18);
        assertEq(token.balanceOf(alice), 1_000e18);
    }

    function test_issue_toUnverified_reverts() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ComplianceToken.ReceiverNotVerified.selector, mallory));
        token.issue(mallory, 1_000e18);
    }

    function test_issue_byNonAgent_reverts() public {
        vm.prank(alice);
        vm.expectRevert(); // AccessControl unauthorized
        token.issue(alice, 1_000e18);
    }

    // ---- transfers ----

    function test_transfer_betweenVerified_succeeds() public {
        _fund(alice, 100e18);
        vm.prank(alice);
        token.transfer(bob, 40e18);
        assertEq(token.balanceOf(bob), 40e18);
        assertEq(token.balanceOf(alice), 60e18);
    }

    function test_transfer_toUnverified_reverts() public {
        _fund(alice, 100e18);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ComplianceToken.ReceiverNotVerified.selector, mallory));
        token.transfer(mallory, 1e18);
    }

    function test_transfer_fromFrozen_reverts() public {
        _fund(alice, 100e18);
        vm.prank(admin);
        token.freeze(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ComplianceToken.AccountIsFrozen.selector, alice));
        token.transfer(bob, 1e18);
    }

    function test_transfer_toFrozen_reverts() public {
        _fund(alice, 100e18);
        vm.prank(admin);
        token.freeze(bob);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ComplianceToken.AccountIsFrozen.selector, bob));
        token.transfer(bob, 1e18);
    }

    // ---- forced transfer (legal recovery) ----

    function test_forcedTransfer_bypassesFreeze() public {
        _fund(alice, 100e18);
        vm.prank(admin);
        token.freeze(alice); // alice frozen (e.g. sanctioned)

        vm.prank(admin);
        token.forcedTransfer(alice, bob, 100e18, "court order 2026-114");

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 100e18);
    }

    function test_forcedTransfer_toUnverified_reverts() public {
        _fund(alice, 100e18);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ComplianceToken.ReceiverNotVerified.selector, mallory));
        token.forcedTransfer(alice, mallory, 1e18, "should fail");
    }

    function test_forcedTransfer_byNonAgent_reverts() public {
        _fund(alice, 100e18);
        vm.prank(alice);
        vm.expectRevert();
        token.forcedTransfer(alice, bob, 1e18, "not allowed");
    }

    // ---- max holders rule ----

    function test_maxHolders_blocksNewHolderOverCap() public {
        vm.prank(admin);
        compliance.setMaxHolders(1); // only one holder allowed

        _fund(alice, 100e18); // alice becomes the 1 holder

        // bob is verified but would be holder #2 -> blocked
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ComplianceToken.TransferNotCompliant.selector, alice, bob, 1e18));
        token.transfer(bob, 1e18);
    }

    function test_maxHolders_allowsExistingHolder() public {
        vm.prank(admin);
        compliance.setMaxHolders(2);
        _fund(alice, 100e18);
        vm.prank(alice);
        token.transfer(bob, 10e18); // bob is holder #2, ok
        // sending more to bob (already a holder) is fine even though at cap
        vm.prank(alice);
        token.transfer(bob, 10e18);
        assertEq(token.balanceOf(bob), 20e18);
    }

    // ---- helper ----

    function _fund(address who, uint256 amount) internal {
        vm.prank(admin);
        token.issue(who, amount);
    }
}
