# Week One — Concrete Steps

You have ~15 hrs/week. Here's how to spend the first week so you end it with a
deployed, tested, compliant token and genuine understanding of why it works.

## Day 1 (~3 hrs) — Setup + read
- Read `01_ERC3643_PRIMER.md` (this folder). Once, properly.
- Install Foundry: `curl -L https://foundry.paradigm.xyz | bash` then `foundryup`
- Read the EIP-3643 Abstract + Motivation. 20 minutes, no more.
- Skim the T-REX repo folder structure on GitHub. Build a mental map.

## Day 2 (~3 hrs) — Scaffold + the token skeleton
- Run the setup commands in `03_SETUP.md`.
- Get `ComplianceToken.sol` compiling (it's in `contracts/`).
- Get the existing tests passing: `forge test`.
- Goal for today: green tests. Don't add anything yet. Understand what's there.

## Day 3 (~3 hrs) — The identity registry
- Study how `IdentityRegistry.sol` is queried by the token's `_update` hook.
- Write a test proving a non-registered address CANNOT receive tokens.
- Write a test proving registration then transfer succeeds.
- This is the core compliance loop. Make sure you can explain it out loud.

## Day 4 (~3 hrs) — Freeze + forced transfer
- Study `freeze` / `unfreeze` and `forcedTransfer`.
- Write tests: frozen account can't send, can't receive, forcedTransfer bypasses
  both (that's the point — it's for court orders).
- Write the test that a NON-admin cannot call any of these.

## Day 5 (~3 hrs) — Invariant testing (the senior move)
- Read the invariant test in `test/`. Understand what it's asserting.
- The invariant: sum of all balances always equals total supply, no matter what
  sequence of mints/transfers/freezes/forced-transfers happens.
- Run it: `forge test --match-test invariant -vvv`
- This is the single most impressive thing in the repo. If Jack asks "how do you
  know your compliance logic is correct?", the answer is "invariant tests" — you
  declare a rule that must always hold and let the fuzzer try thousands of random
  action sequences to break it.

## End of week 1 checkpoint
You should be able to say, truthfully:
- "I built a compliant token with identity-gated transfers, freeze controls, and
  forced transfer for legal recovery."
- "I proved the compliance rules can't be bypassed with negative-case tests."
- "I wrote an invariant test asserting balances always sum to supply across any
  sequence of actions."

That's already more than most candidates have. Weeks 2+ deepen it (deploy to
testnet, add compliance modules like max-holders and lockups, then the off-chain
registry in Phase 2).

## A note on using AI while building
Use it as a tutor, not an autocomplete. When you paste a contract and it explains
it, make yourself re-explain it back in your own words. The goal is that you can
defend every line to a CTO. If you can't explain why a line is there, you don't
understand it yet — and that's the gap an interview will find.
