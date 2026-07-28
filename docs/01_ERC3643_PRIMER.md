# ERC-3643 (T-REX) — The Primer

Read this once before you write any code. You don't need to memorise it. You need
to understand *why* the standard is shaped the way it is, because that "why" is
exactly what a CTO like Jack will probe.

## The one-sentence version

ERC-3643 is an ERC-20 token where **every transfer asks a question first**:
"Is this transfer allowed?" If the answer is no, the transfer reverts.

That's it. Everything else is machinery to answer that question well.

## Why ERC-20 alone doesn't work for regulated assets

A normal ERC-20 `transfer` moves tokens from A to B. It checks one thing: does A
have enough balance? For a regulated security that's not enough. You also need:

- Is B a verified, KYC'd investor?
- Is B allowed to hold this asset in their jurisdiction?
- Is A frozen (sanctions, court order)?
- Would this transfer break a rule (max holders, lockup period)?

ERC-3643 adds a layer that checks all of that on-chain, *before* the balance moves.

## The four pieces (this is the mental model)

ERC-3643 deliberately splits responsibilities across separate contracts. When you
first see it, it feels over-engineered. It isn't — the separation is the point,
because each piece changes at a different rate and for different reasons.

```
┌─────────────────────────────────────────────────────────┐
│                        TOKEN                            │
│   ERC-20 + the transfer hook that asks "am I allowed?"  │
└───────────────┬───────────────────────┬─────────────────┘
                │                       │
                ▼                       ▼
   ┌────────────────────────┐   ┌────────────────────────┐
   │   IDENTITY REGISTRY    │   │      COMPLIANCE        │
   │  "Who is this person   │   │  "Does this transfer   │
   │   and are they valid?" │   │   break any rules?"    │
   └───────────┬────────────┘   └────────────────────────┘
               │
               ▼
   ┌────────────────────────┐
   │   IDENTITY STORAGE /    │
   │   ONCHAINID + CLAIMS    │
   │  "The actual identity   │
   │   data and who vouches  │
   │   for it"               │
   └────────────────────────┘
```

### 1. The Token
An ERC-20 that overrides the transfer logic. Before any transfer it calls out to
the Identity Registry ("is the receiver valid?") and Compliance ("is this transfer
allowed?"). If either says no, it reverts.

### 2. The Identity Registry
Answers "is this address a verified investor?" It maps a wallet address to an
on-chain identity, and checks that identity holds the required *claims* (e.g. "KYC
passed", "accredited", "country = UK"). If the investor's verification expires,
they silently stop being able to receive tokens. No code change needed.

### 3. Compliance
Answers "does this specific transfer break a rule?" This is where modular rules
live: max number of holders, per-country limits, lockup periods, max balance per
investor. It's separate from identity because these rules change often and you want
to swap them without touching the token or the registry.

### 4. Identity / Claims (OnchainID)
The lowest layer. An investor's identity is itself a contract that holds *claims* —
signed statements from trusted parties ("this KYC provider confirms this person
passed KYC on this date"). The registry trusts certain claim issuers; the identity
holds the claims. This is the part that makes the whole thing decentralised rather
than one big whitelist controlled by one admin.

## The key insight to say out loud in an interview

> "The reason ERC-3643 splits identity from compliance is that they change for
> different reasons. Identity changes when an investor's KYC status changes.
> Compliance changes when the *rules* change — a new jurisdiction, a new holding
> limit. Keeping them separate means you can update the rulebook without
> re-verifying every investor, and re-verify an investor without touching the
> rules. That separation is the actual design insight, not the token itself."

If you understand that paragraph, you understand ERC-3643 better than most people
who list it on their CV.

## What you're going to build

You will NOT rebuild the full T-REX suite from scratch — that's thousands of lines
and misses the point. Instead:

**Phase 1 (now):** Build a simplified but *honest* version of this architecture —
a token with a transfer hook, a registry contract it queries, and a compliance
contract for rules. Same shape as ERC-3643, small enough to fully understand and
test. You'll read the real T-REX code alongside so you can speak to how the real
one differs.

**Later:** Swap your simplified registry/compliance for the real T-REX interfaces,
so your token becomes genuinely ERC-3643-compatible. That progression — "I built
the pattern myself to understand it, then adopted the standard" — is a great story.

## Reading list (do this in order, don't binge it all today)

1. The ERC-3643 spec itself (eips.ethereum.org, EIP-3643) — read the Abstract and
   Motivation sections today. Skim the rest.
2. The Tokeny T-REX repo on GitHub (ERC-3643/T-REX) — just read the contract
   *names* and folder structure today. You're building a map, not memorising.
3. OnchainID repo — skim only. Understand that claims = signed statements.

Come back to 2 and 3 properly during Phase 1 as you build the equivalent pieces.

## The single rule that keeps you honest

Every time you add a feature, write the test that proves it **can't be bypassed**
before you move on. The compliance logic is only real if you've proven the negative
case — that a non-whitelisted address genuinely cannot receive tokens, that a
frozen account genuinely cannot send. That's the actual engineering. The happy path
is the easy 20%.
