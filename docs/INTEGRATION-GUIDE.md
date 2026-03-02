# Integration Guide (Backend <-> DAML)

This guide maps `ALPEND-PREDICTIONS-` backend flows to Raven contracts.

## Components

- Backend: `/Users/prajwalghate/Documents/Work/canton/ALPEND-PREDICTIONS-`
- Contracts: `/Users/prajwalghate/Documents/Work/canton/raven-contracts/core`
- Upload DAR: `/Users/prajwalghate/Documents/Work/canton/raven-contracts/core/.daml/dist/raven-contracts-core-0.2.0.dar`

## Party Mapping

Define three Canton parties at minimum:

- `operator`: executes mint/payout/settlement commands
- `house`: receives opposite-side tokens and internal residuals
- `oracle`: settlement submitter (can be same as `operator` for now)

For current no-oracle mode, set `oracle = operator` at series creation.

## Backend Storage Requirements

Add CID mapping tables (recommended):

- `series_contracts(series_id, option_series_cid, vault_cid, updated_at)`
- `position_contracts(position_id, token_cid, side, quantity, updated_at)`
- `ledger_events(local_entity, local_id, daml_tx_id, command_name, created_at)`

Without these, stale CID failures are guaranteed.

## API-to-Contract Mapping

## 1. Series create (`/admin/series`)

On DB series create:

1. Create `OptionSeries` on ledger.
2. Create initial `CollateralVault` for `seriesRef`.
3. Persist returned `option_series_cid` and `vault_cid`.

## 2. BUY trade (`/trade` with `trade_type=BUY`)

Current backend computes AMM quote off-chain. Keep that unchanged.

Ledger steps:

1. Load current `vault_cid` for `series_id`.
2. Execute `MintCompleteSets(trader, desiredSide, quantity, depositAmount)`.
3. Persist new `vault_cid` from return value.
4. Persist trader token CID to `position_contracts`.
5. Persist opposite-side house token CID for settlement inventory.
6. Write `daml_tx_id` into `trades.tx_hash`.

## 3. SELL trade (`/trade` with `trade_type=SELL`)

Ledger steps:

1. Resolve seller token CID(s) from `position_contracts`.
2. If partial sell, run `Split` first, then choose sold CID.
3. Seller executes `Transfer(newOwner = house)`.
4. Operator executes `ReleasePayout(trader, amount, reason)` on latest vault CID.
5. Persist new vault CID and payout CID; update tx hash.

## 4. Settlement worker

Current backend fetches price and writes DB settlement. In hybrid mode:

1. Determine resolved price (backend source unchanged for now).
2. Execute `SubmitSettlement(resolvedPrice)` on latest `OptionSeries` CID.
3. Collect complete winning and losing token CID lists for series.
4. Execute `SettleAndPay(seriesCid, winningTokenCids, losingTokenCids)` on latest vault CID.
5. Persist settlement record CID and payout CIDs.
6. Update DB status and payout queue based on resulting ledger events.

## Idempotency Rules

Required to avoid duplicate payouts:

- Use deterministic command IDs per business action:
  - `buy:<trade_id>:mint`
  - `sell:<trade_id>:transfer`
  - `sell:<trade_id>:payout`
  - `settle:<series_id>:submit`
  - `settle:<series_id>:finalize`
- On retry, re-query by local id and command id before resubmitting.

## Failure Handling

## Case A: Ledger success, DB failure

- Reconcile by reading transaction tree and updating DB from ledger result.
- Never resubmit blindly; use command id + event reconciliation.

## Case B: DB success, ledger failure

- Mark row as failed/pending and retry command with same idempotency key.

## Case C: stale CID

- Fetch latest CID from mapping table and retry once.
- If mismatch persists, trigger manual reconciliation.

## Validation Checklist

Before enabling production traffic:

- `dpm build --all` and `dpm test` pass
- Party mapping validated on target participant
- CID mapping migrations applied
- Replay/idempotency checks in place
- Settlement dry-run on test series completed
