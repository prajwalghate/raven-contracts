# Audit Test Plan

## Objective

Validate Raven core contracts for correctness, authorization safety, accounting invariants, and integration resilience before production rollout.

## Scope

- Package: `raven-contracts-core`
- Modules:
  - `core/src/Types.daml`
  - `core/src/Series.daml`
  - `core/src/OptionToken.daml`
  - `core/src/Vault.daml`
- Test package:
  - `tests/src/Test/Main.daml`

## Baseline Commands

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts
dpm build --all

cd /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests
dpm test
```

Expected baseline today:

- `testHybridLifecycle`: pass
- `testNegativeChecks`: pass
- `setup`: pass

## Audit Layers

## 1. Static Contract Review

Checklist:

- Confirm all `controller` clauses match business authority:
  - operator-only: mint/payout/settle
  - owner-only: token transfer/split
  - oracle/operator mode for settlement submit
- Confirm no unintended observer data leakage.
- Confirm each consuming choice returns replacement CID where state mutates.

## 2. Invariant Validation

Must hold in all test scenarios:

- Time ordering: `start < end < expiry`
- Mint floor: `depositAmount >= quantity`
- Reserve floor pre-settlement: `remainingReserve >= totalSetsMinted`
- Settlement accounting:
  - winner quantity sum == total minted sets
  - loser quantity sum == total minted sets
- Duplicate CID rejection in settlement lists

## 3. Authorization Abuse Tests

Add/verify negative tests for:

- Non-operator trying `MintCompleteSets`
- Non-operator trying `ReleasePayout`
- Non-owner trying token `Transfer`
- Non-owner trying token `Split`
- Non-oracle (or non-authorized settlement actor) trying `SubmitSettlement`

## 4. Ledger State Transition Tests

For each consuming choice, assert old CID is dead and new CID exists:

- vault CID rollover after mint/payout
- token CID rollover after split/transfer
- series CID rollover after settlement submit

## 5. Accounting Reconciliation Tests

Run deterministic reconciliation after test flow:

- `sum(active winner payouts)` equals external winner quantity
- `houseResidual = vaultReserveBeforeSettlement - externalWinnerPayout`
- no active option tokens remain after full settlement

## 6. Integration Fault Tests (Backend-Centric)

Simulate and test these failures in integration harness:

- stale CID usage (expected ledger reject)
- duplicate command retries (idempotency required)
- partial DB commit after successful ledger tx (recovery/replay required)
- wrong token list in settlement call (expected reject)

## 7. Operational Readiness Tests

- Build artifacts reproducibility
- DAR fingerprint/version pinning
- Party mapping validation (`operator`, `oracle`, `house`)
- Rollback/redeploy plan with previous DAR retained

## Sign-Off Criteria

Release only when:

- All script tests green
- All audit checklist items marked complete
- At least one external reviewer confirms invariant and auth checks
- Integration fault tests documented with expected outcomes

## Suggested Test Backlog Additions

- settlement with zero external winners (house-only winners)
- settlement with many split CIDs per user
- explicit stale-CID test case
- explicit duplicate-CID settlement input test
