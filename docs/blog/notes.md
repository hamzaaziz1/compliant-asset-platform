# blog notes — running capture

working notes for the build-log posts. one-liners captured as we build, grouped by
which post they belong to. not prose yet — raw material. framing for all posts:
honest "learning build" angle, first person, lowercase-ish, reader is another
smart contract engineer. lead with EVM engineering, use compliance reasoning to
explain why the mechanics exist (~60/40).

three posts planned from phase 1:
- **P1** — identity and compliance as separate contracts (the architecture decision)
- **P2** — the transfer hook mechanics (`_update`, mint/burn routing, `_forced`)
- **P3** — testing compliance you can't bypass (negative cases + invariants)

phase 2 (off-chain registry + queue) and phase 3 (liquid) will spawn their own
posts later.

---

## P1 — identity / compliance separation

- the split: two contracts because identity changes when an investor's kyc status
  changes, rules change when the *rulebook* changes. different rates, different
  reasons. keeping them separate means updating the rulebook doesn't require
  re-verifying investors, and vice versa. that's the actual erc-3643 design
  insight, not the token.

- sidebar — "why not just register the zero address as verified to avoid the
  mint/burn branch?" answer: zero isn't a party, it's a sentinel for 'no owner'.
  registering it breaks safe burn semantics, lets tokens get sent to an
  unrecoverable black hole while passing compliance, and corrupts the holder count
  into counting the void. and the invariant would still pass because you've
  corrupted both sides consistently — the dangerous kind of wrong. costs you the
  structural meaning of null to save two boolean checks.

---

## P2 — the transfer hook mechanics

- the heart of the system is one function: `_update`. OZ v5 routes every
  mint/burn/transfer through it, so overriding it puts all compliance in one place.
  everything else (registry, compliance, roles) exists to serve those ~15 lines.

- mint/burn skip is a *correctness requirement*, not an optimisation — zero address
  is never a verified investor, so running receiver verification in the hook would
  make burn (and mint) revert every time. gate issuance in `issue()` where there's
  a real party to check, skip the hook for supply changes. good concrete example of
  "trace the actual value, don't reason about intent."

- the `_forced` flag is a plain boolean (custom, arbitrary name) — NOT a built-in.
  distinction worth making in the post: `_update` is the OZ mechanism you hook into;
  `_forced` is just a variable you declared. the cleverness is using the built-in
  routing, not the variable.

- why `_forced` must be a state variable: you're in `forcedTransfer`, you want the
  `_update` hook to skip checks for this one call, but you can't pass a parameter —
  the call chain is `forcedTransfer → _transfer → _update` and you don't control
  OZ's `_transfer` signature. storage is the only side channel to smuggle intent
  past a function whose signature you can't change.

- `_forced` is permissive not defensive — opposite of a reentrancy guard. a guard
  flips on to *block* re-entry; `_forced` flips on to *allow* a skip. same shape,
  opposite intent. bouncer vs backstage pass.

- the `_forced` reentrancy window: flag disables checks between set-true and
  set-false. safe *here* only because plain ERC-20 `super._update` makes no external
  calls, so nothing can re-enter while it's open. but contingent — add any receiver
  callback / ERC-777-style hook and the window goes live. harden with `nonReentrant`
  on `forcedTransfer` or strict no-external-calls discipline.

- **forced transfer as feature not backdoor (the strongest section).** yes it's
  dangerous — an agent can move anyone's tokens. but for a regulated security the
  power is mandatory: court-ordered seizure, estate settlement, sanctions
  confiscation, key-loss reissuance. a token that *can't* do these is unshippable —
  it can't comply with the law it lives inside. a defi purist sees a backdoor; a
  securities lawyer sees a token without it as un-issuable. the flaw isn't the
  power, it's implementing it single-key / instant / unlogged. reframe: not "is
  this dangerous" but "this is necessarily dangerous — contain the blast radius."

- containment = multisig holds the agent role + timelock delays it + events expose
  it. current build has the auditability piece (the `reason` string + `ForcedTransfer`
  event) but the role is still a single admin address — deliberate phase-1 gap,
  would harden to multisig + timelock before production. naming your own gaps is a
  credibility signal.

- multisig — the answer to "how do you hold a dangerous power safely." key insight:
  you don't fix `forcedTransfer` by changing the function, you change *who can call
  it* — grant AGENT_ROLE to a Safe contract instead of an EOA. token needs zero
  changes because access control already just checks role-holding. mechanism: Safe =
  contract with N owners + threshold, verifies N ECDSA sigs on-chain via ecrecover
  before executing, reverts below threshold. timelock stacks on top for a public
  delay window. blast-radius arc: EOA (1 key) → Safe (N keys) → Safe+Timelock
  (N keys + public delay). ties back to the ECDSA primitive — multisig is just
  "collect + verify N signatures on-chain."

- multisig across chains (could be a P2 sidebar or fold into P3 multi-chain): the
  concept (threshold approval) is universal, the mechanism differs by architecture.
  EVM: application-layer contract (Safe), chain has no native multisig account.
  Cosmos: protocol-native, built into SDK key management, enforced at tx
  verification before module logic even runs. Bitcoin/Liquid: script-native
  (OP_CHECKMULTISIG), and Liquid's federation *is itself* a multisig — the chain's
  foundation. through-line: you never implement multisig yourself, you check
  authorization in-app and delegate the threshold mechanism to the platform's native
  tool.

---

## P3 — testing compliance you can't bypass

- first run was clean: 14 tests green, both invariants holding over 12,800 calls
  per run with zero reverts.

- `fail_on_revert = false` in the invariant config is a deliberate choice worth a
  sentence: a *blocked* transfer during fuzzing is correct behaviour, not a failure.
  the invariant doesn't care that individual calls revert — it only cares that the
  end-state rule always holds.

- the `_bal` mirror drift is the perfect worked example for "why invariants, not
  just unit tests." ModularCompliance keeps its own hand-maintained copy of
  balances to decide new-holder status and maintain `holderCount`. if that mirror
  drifts from real token balances: `canTransfer` makes wrong new-holder decisions,
  and `holderCount` silently lies — corrupting the reportable cap table with no
  visible error. self-consistent and wrong again.

- `test_maxHolders_*` assumes the mirror is correct — it's a fixed 2-3 operation
  scenario. only `invariant_holderCountMatchesReality` proves the mirror *stays*
  correct: it recomputes the true holder count from real balances and asserts the
  compliance counter matches, after every random action sequence the fuzzer throws.

- core idea for the whole post: unit tests check scenarios you thought of,
  invariants check properties hold across scenarios you didn't. hand-maintained
  state mirrors (counters, caches) are exactly where you reach for invariants,
  because drift is silent.

---

## still to capture (phase 1 remaining build)

- country-cap rule extension (next build session) — first genuinely self-authored
  commit. uses `investorCountry` the registry already tracks. real-world parallel:
  jurisdictional holding limits in regulated tokens.
