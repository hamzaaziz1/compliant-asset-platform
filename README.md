# Compliant Asset Platform

A permissioned security-token system modelling how regulated real-world assets
(private credit, real estate, funds) are tokenized on-chain. Built as a study of
the ERC-3643 (T-REX) architecture, then extended into a full issuance platform.

> Status: Phase 1 — on-chain compliance core. See `docs/` for the build plan.

## Why this exists

A standard ERC-20 lets anyone hold or send tokens. Regulated securities can't work
that way — only verified investors may hold them, some accounts must be freezable,
and legal recovery (court orders, sanctions) must be possible. This project
implements the compliance-gated transfer pattern that makes regulated tokenization
possible on a permissionless chain.

## Architecture

The design follows ERC-3643's separation of concerns:

- **`ComplianceToken`** — ERC-20 whose every transfer is gated by two questions.
- **`IdentityRegistry`** — "is the receiver a verified investor?"
- **`ModularCompliance`** — "does this transfer break any rules?" (e.g. max holders)

The token asks both before moving any balance. Identity and rules live in separate
contracts because they change for different reasons and at different rates — the
core insight behind ERC-3643.

## Features (Phase 1)

- Identity-gated transfers — unverified addresses cannot receive
- Freeze / unfreeze accounts (sanctions, disputes)
- Forced transfer with on-chain audit reason (court-ordered recovery)
- Modular compliance with a max-holders rule (extensible to lockups, country caps)
- Role-based access control (admin / agent)
- Full Foundry test suite including **invariant tests** proving balances always
  sum to supply across any random sequence of actions

## Roadmap

- **Phase 1** (now): on-chain compliance core ✅ contracts + tests
- **Phase 2**: off-chain compliance registry (KYC/jurisdiction/lockups), a
  transaction queue with proper nonce management, and an event indexer maintaining
  a queryable cap table
- **Phase 3**: second chain integration (Liquid Network) behind a common issuance
  interface, demonstrating multi-chain tokenization

## Getting started

See `docs/03_SETUP.md`. In short:
```bash
forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts@v5.0.2
forge test -vv
forge test --match-contract Invariant -vvv
```

## Docs

- `docs/01_ERC3643_PRIMER.md` — the standard explained from scratch
- `docs/02_WEEK_ONE.md` — day-by-day build plan
- `docs/03_SETUP.md` — local setup

## Disclaimer

Educational project. Not audited, not production code, not financial or legal advice.
