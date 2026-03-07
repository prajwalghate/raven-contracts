# Developer Guide

This guide is the practical reference for developers integrating and extending Raven contracts.

## 1. Core mental model

- Every mutable ledger state is represented by contract replacement (new CID).
- Never reuse consumed CIDs in backend commands.
- Vault and accounting are series-scoped (`seriesRef`), not global.

## 2. Current package artifacts

- Core DAR: `/Users/prajwalghate/Documents/Work/canton/raven-contracts/core/.daml/dist/raven-contracts-0.2.1.dar`
- Tests DAR: `/Users/prajwalghate/Documents/Work/canton/raven-contracts/tests/.daml/dist/raven-contracts-tests-0.2.1.dar`

## 3. Contract modules

- `Types.daml`: enums and settlement payload.
- `Series.daml`: series lifecycle and oracle settlement.
- `OptionToken.daml`: option tokens, payouts, lot records, audit records.
- `Vault.daml`: reserve accounting, mint/sell payout/settlement, seed liquidity controls.

## 4. Lifecycle summary

1. Create `OptionSeries`.
2. Create `CollateralVault` with initial seed (`ccReserve`, `initialSeedLiquidity`).
3. Optional post-create seed operations:
   - `AddSeedLiquidity`
   - `RemoveSeedLiquidity`
4. User buy via `MintCompleteSets`.
5. User sell via `Split/Transfer` + operator `ReleasePayout`.
6. Oracle `SubmitSettlement`.
7. Operator `SettleAndPay`.

## 5. Seed liquidity model

`CollateralVault` fields:
- `ccReserve`
- `initialSeedLiquidity`
- `additionalSeedLiquidity`
- `totalSetsMinted`

Rules:
- `AddSeedLiquidity` increases reserve and `additionalSeedLiquidity`.
- `RemoveSeedLiquidity` can only withdraw from `additionalSeedLiquidity`.
- Reserve must stay above collateral floor (`totalSetsMinted`) and seeded floor constraints.

## 6. Position accounting model

- Original quantity source: `PositionLot.originalQuantity`.
- Remaining quantity source: sum of active `OptionToken.quantity` by user/series/side.
- Event history source: `PositionLotEvent`.

`PositionLotEvent.eventKind`:
- `LotEventMint`
- `LotEventSell`
- `LotEventSettlementWin`
- `LotEventSettlementLoss`

## 7. Memo/context metadata model

Inputs carried in main vault flows:
- `metadata` (`externalUserId`, `userMemo`)
- `choiceContext`
- `reason`

Stored on ledger in:
- `ActivityAudit`
- `PositionLotEvent`
- `CCPayout` reason/source lot linkage

Splice-style metadata map keys:
- `splice.lfdecentralizedtrust.org/reason`
- `raven.market/external_user_id`
- `raven.market/user_memo`

## 8. Splice activity marker integration

- Optional input: `featuredAppRightCid`.
- If provided, vault choices call:
  `FeaturedAppRight_CreateActivityMarker`.
- If not provided, flow continues without marker creation.

## 9. Backend command requirements

- Persist latest CIDs after every consuming choice.
- Use deterministic command IDs for idempotency.
- On retry, lookup by command-id/local-id before submit.
- Reconcile DB from ledger events after partial failures.

## 10. Testing commands

Build:
```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts
dpm build --all
```

Tests:
```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests
dpm test
```

Script against sandbox (static time required):
```bash
dpm script \
  --dar /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests/.daml/dist/raven-contracts-tests-0.2.1.dar \
  --script-name Test.Main:setup \
  --static-time \
  --ledger-host 127.0.0.1 \
  --ledger-port 6865
```

## 11. Common mistakes

- Running scripts without `--static-time` when tests use `passTime`.
- Using stale vault/token/series CIDs.
- Releasing payout without house-owned sold token CID.
- Treating reserves as cross-series shared pool.

## 12. What to extend next safely

- Add explicit payout lifecycle statuses on-ledger (if needed).
- Add governance around seed add/remove approvals.
- Add richer settlement batching/index projections in backend.
