// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ComplianceToken} from "../contracts/ComplianceToken.sol";
import {IdentityRegistry} from "../contracts/IdentityRegistry.sol";
import {ModularCompliance} from "../contracts/ModularCompliance.sol";

/**
 * INVARIANT TESTING — the thing to talk about in an interview.
 *
 * A unit test checks one scenario you thought of. An invariant test declares a
 * rule that must ALWAYS hold, then lets Foundry fire thousands of random action
 * sequences (issue / transfer / freeze / forcedTransfer in random order with
 * random amounts and actors) trying to break it.
 *
 * The rule here: the sum of all holders' balances always equals totalSupply, and
 * the compliance holder counter never disagrees with reality. If any random
 * sequence can break that, you have a real bug. This is how you gain confidence
 * that money-handling logic is correct beyond the cases you happened to imagine.
 */

/// @dev Handler exposes the actions the fuzzer is allowed to call, over a fixed
///      set of actors, so sequences stay meaningful (not random reverting noise).
contract Handler is Test {
    ComplianceToken public token;
    IdentityRegistry public registry;
    address public admin;

    address[] public actors;
    uint256 public ghost_mintedMinusBurned;

    constructor(ComplianceToken token_, IdentityRegistry registry_, address admin_, address[] memory actors_) {
        token = token_;
        registry = registry_;
        admin = admin_;
        actors = actors_;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function issue(uint256 toSeed, uint256 amount) public {
        address to = _actor(toSeed);
        amount = bound(amount, 0, 1_000_000e18);
        vm.prank(admin);
        try token.issue(to, amount) {
            ghost_mintedMinusBurned += amount;
        } catch {}
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        uint256 bal = token.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        vm.prank(from);
        try token.transfer(to, amount) {} catch {}
    }

    function freeze(uint256 seed, bool on) public {
        address who = _actor(seed);
        vm.prank(admin);
        if (on) token.freeze(who);
        else token.unfreeze(who);
    }

    function forcedTransfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);
        uint256 bal = token.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 0, bal);
        vm.prank(admin);
        try token.forcedTransfer(from, to, amount, "fuzz") {} catch {}
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }

    function actorAt(uint256 i) external view returns (address) {
        return actors[i];
    }
}

contract ComplianceTokenInvariant is StdInvariant, Test {
    ComplianceToken token;
    IdentityRegistry registry;
    ModularCompliance compliance;
    Handler handler;

    address admin = makeAddr("admin");

    function setUp() public {
        vm.startPrank(admin);
        registry = new IdentityRegistry(admin);
        compliance = new ModularCompliance(admin);
        token = new ComplianceToken("Private Credit Note", "PCN", address(registry), address(compliance), admin);
        compliance.bindToken(address(token));

        address[] memory actors = new address[](4);
        actors[0] = makeAddr("a0");
        actors[1] = makeAddr("a1");
        actors[2] = makeAddr("a2");
        actors[3] = makeAddr("a3");
        for (uint256 i = 0; i < actors.length; i++) {
            registry.registerInvestor(actors[i], 826);
        }
        vm.stopPrank();

        handler = new Handler(token, registry, admin, actors);
        targetContract(address(handler));
    }

    /// @notice sum of all actor balances must always equal totalSupply
    function invariant_balancesSumToTotalSupply() public view {
        uint256 sum;
        uint256 n = handler.actorsLength();
        for (uint256 i = 0; i < n; i++) {
            sum += token.balanceOf(handler.actorAt(i));
        }
        assertEq(sum, token.totalSupply(), "balances must sum to total supply");
    }

    /// @notice compliance holder counter must equal the real number of non-zero holders
    function invariant_holderCountMatchesReality() public view {
        uint256 real;
        uint256 n = handler.actorsLength();
        for (uint256 i = 0; i < n; i++) {
            if (token.balanceOf(handler.actorAt(i)) > 0) real++;
        }
        assertEq(compliance.holderCount(), real, "holder count must match reality");
    }
}
