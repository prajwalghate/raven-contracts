# Creation Plan

## Goal

Deliver a production-ready DAML package for Raven hybrid options market on Canton, with local tests and clean handoff docs.

## Phase 1: Domain Model Lock

1. Finalize series lifecycle and roles (`operator`, `oracle`, `house`, `trader`).
2. Encode invariants:
   - `start < end < expiry`
   - `deposit >= minted sets`
   - vault reserve never drops below collateral floor pre-settlement
   - settlement token quantities must match total minted sets per side
3. Define deterministic winner rule: `resolvedPrice > strike => CALL, else PUT`.

## Phase 2: Core Templates

1. `OptionSeries` for metadata + settlement commit.
2. `OptionToken` for CALL/PUT ownership and transfer.
3. `CollateralVault` for:
   - complete-set minting
   - payout release for sell/swap
   - atomic settlement execution and final report
4. `CCPayout` and `SeriesSettlementRecord` as auditable outputs.

## Phase 3: Test Coverage

1. Happy-path E2E:
   - buy/mint
   - partial sell
   - oracle settlement
   - atomic settle and payout
2. Negative tests:
   - unauthorized mint
   - premature settlement
   - reserve floor violation

## Phase 4: Integration Readiness

1. Document backend command mapping (`/trade`, settlement worker).
2. Document contract-id persistence requirements.
3. Build DAR and provide handoff steps for Canton node team.

## Phase 5: Hardening Backlog (Next Iteration)

1. Party-level whitelisting and trader licensing templates.
2. Explicit idempotency keys to guard retries.
3. Batch pagination for very large settlement token sets.
4. Multi-package split (core assets vs admin workflows).
