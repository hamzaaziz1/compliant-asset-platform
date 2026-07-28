# Setup — Run This On Your Machine

This project uses Foundry. These files can't be compiled in the chat environment
(no internet for tooling there), so you run them locally. Takes ~10 minutes.

## 1. Install Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## 2. Initialise git + install dependencies
From inside the project folder:
```bash
git init
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts
```
`forge install` will place these under `lib/`. The remappings in `foundry.toml`
already point at them.

## 3. Build
```bash
forge build
```
Expect it to compile the four contracts (ComplianceToken, IdentityRegistry,
ModularCompliance, and the two interfaces).

## 4. Run the tests
```bash
forge test -vv
```
You should see the unit tests pass. Then run the invariants specifically:
```bash
forge test --match-contract Invariant -vvv
```

## 5. Gas report (optional, nice to know)
```bash
forge test --gas-report
```

## Troubleshooting
- **Remapping errors:** make sure `forge install` actually created
  `lib/openzeppelin-contracts` and `lib/forge-std`. Re-run if not.
- **Solc version:** foundry.toml pins 0.8.24. If it complains, run `foundryup`
  again to get a recent toolchain.
- **OZ v5 vs v4:** this code targets OpenZeppelin v5 (the `_update` hook). If
  `forge install` pulled v4, the override signature differs — install v5:
  `forge install OpenZeppelin/openzeppelin-contracts@v5.0.2`

## Next
Once green, go back to `02_WEEK_ONE.md` and work through days 3–5. The code is
already here; the point of the week is that you can *explain and extend* it, not
just run it.
