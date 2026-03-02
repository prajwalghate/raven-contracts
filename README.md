# Raven Contracts (Canton DAML)

Simplified Hybrid V1 DAML contract package for Raven's options market on Canton.

## Production Split

This repo is split into two packages:

- `core`: deployable ledger contracts (no `daml-script` dependency)
- `tests`: script/test package that depends on `core` DAR

This avoids uploading test dependencies to production participants.

## Scope

Hybrid architecture from `raven_flow.html`:

- `OptionSeries`: metadata and settlement state
- `CollateralVault`: CC escrow, complete-set mint, payout release, settlement finalization
- `OptionToken`: CALL/PUT ownership contracts
- `CCPayout` + `SeriesSettlementRecord`: payout and audit artifacts

AMM pricing and pool state remain off-chain.

## Layout

- `multi-package.yaml`: package build graph
- `core/daml.yaml`: deployable package config
- `core/src/*.daml`: production templates and choices
- `tests/daml.yaml`: test package config
- `tests/src/Test/Main.daml`: end-to-end and negative tests
- `docs/`: specs, handoff, and learning docs

## Local Commands

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts

# Build all packages (core + tests)
dpm build --all

# Run tests package scripts
cd tests
dpm test
```

## Output DARs

- Core DAR (upload target):
  - `/Users/prajwalghate/Documents/Work/canton/raven-contracts/core/.daml/dist/raven-contracts-core-0.2.0.dar`
- Tests DAR (local/testing only):
  - `/Users/prajwalghate/Documents/Work/canton/raven-contracts/tests/.daml/dist/raven-contracts-tests-0.2.0.dar`

## Integration Model (with ALPEND-PREDICTIONS-)

- Backend computes AMM quotes/payouts off-chain.
- Backend submits DAML commands for mint/sell/settlement.
- Backend stores returned transaction IDs and CIDs in PostgreSQL.
- Canton ledger is source of truth for custody and settlement outcomes.

Read next:

- `docs/CONTRACT-SPEC.md`
- `docs/HANDOFF.md`
- `docs/NOOB-DEVELOPER-GUIDE.md`
- `docs/SANDBOX-AND-SCRIPT-TESTING.md`
