# Raven Canton DAML Onboarding Guide

This is the single entry doc for a new engineer to get productive with Raven’s Canton DAML contracts.

## 1) Project Map

Workspace:
- `/Users/prajwalghate/Documents/Work/canton/raven-contracts`

Packages:
- `core` (deployable DAML contracts)
- `tests` (Daml Script tests)

Key files:
- `core/src/Types.daml`
- `core/src/Series.daml`
- `core/src/Vault.daml`
- `core/src/OptionToken.daml`
- `tests/src/Test/Main.daml`

Docs to read next:
- `docs/CONTRACT-SPEC.md`
- `docs/FUNCTIONALITY-FLOW.md`
- `docs/INTEGRATION-GUIDE.md`
- `docs/SANDBOX-AND-SCRIPT-TESTING.md`
- `docs/AUDIT-PLAN.md`

External Canton/Daml references (latest):
- Digital Asset Daml Assistant + component how-tos
- How to build DAR files
- How to run Daml tests
- Featured App Activity Marker (CIP-0047)
- Canton Network Token Standard (CIP-0056)

Reference links (paste into browser):
```text
https://get-docs.digitalasset.com/build/3.3/component-howtos/index.html
https://get-docs.digitalasset.com/build/3.3/component-howtos/smart-contracts/assistant.html
https://get-docs.digitalasset.com/build/3.3/sdlc-howtos/smart-contracts/build/how-to-build-dar-files.html
https://get-docs.digitalasset.com/build/3.3/tutorials/smart-contracts/tests.html
https://github.com/global-synchronizer-foundation/cips/blob/main/cip-0047/cip-0047.md
https://github.com/global-synchronizer-foundation/cips/blob/main/cip-0056/cip-0056.md
https://github.com/global-synchronizer-foundation/cips/blob/main/cip-0057/cip-0057.md#abstract
```

## 2) What this system does

Raven provides a hybrid options market:
- AMM pricing is off-chain (backend)
- Custody, minting, payouts, and settlement are on-ledger (DAML)
- Each options series has its own vault and isolated accounting

## 3) Contract model (short)

Templates:
- `OptionSeries`: series metadata + settlement state
- `CollateralVault`: reserve accounting + mint/sell/settle + seed add/remove
- `OptionToken`: CALL/PUT positions
- `CCPayout`: payout entitlements
- `PositionLot` + `PositionLotEvent`: original quantity + event timeline
- `ActivityAudit`: reason/memo/context audit log
- `SeriesSettlementRecord`: immutable settlement report

## 4) Parties

- `operator`: main contract authority (mint/payout/seed/settle)
- `oracle`: submits settlement price
- `house`: treasury inventory for opposite-side tokens
- `trader`: user

## 5) Core flows (mental model)

1. Create series + vault with initial seed (`ccReserve`, `initialSeedLiquidity`).
2. Optional seed top-up or removal (`AddSeedLiquidity`, `RemoveSeedLiquidity`).
3. BUY:
   - `MintCompleteSets` (trader gets desired side, house gets opposite side)
   - Creates `PositionLot` and `PositionLotEvent` (mint)
4. SELL:
   - `Split` optional, `Transfer` token to house
   - `ReleasePayout` by operator (creates `CCPayout` + lot event)
5. SETTLEMENT:
   - `SubmitSettlement` by oracle
   - `SettleAndPay` by operator (archives tokens, creates payouts, settlement record)

## 6) Metadata and context (must understand)

Each main vault choice takes:
- `metadata` (externalUserId, userMemo)
- `choiceContext` (extra backend data)
- `reason` (business code)
- optional `featuredAppRightCid`

Metadata is stored in:
- `ActivityAudit`
- `PositionLotEvent`
- `CCPayout`

## 7) Featured app activity markers

- Optional input: `featuredAppRightCid`
- If provided, `FeaturedAppRight_CreateActivityMarker` is called
- If None, main flow still works without markers

## 8) Seed liquidity rules

- `initialSeedLiquidity` is set at vault creation
- `AddSeedLiquidity` increases `additionalSeedLiquidity`
- `RemoveSeedLiquidity` only removes from additional seed
- Reserve must always stay >= `totalSetsMinted`

## 9) How to run tests

Build:
```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts
dpm build --all
```

Run tests:
```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests
dpm test
```

Run script against sandbox (static-time required):
```bash
dpm script \
  --dar /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests/.daml/dist/raven-contracts-tests-0.2.1.dar \
  --script-name Test.Main:setup \
  --static-time \
  --ledger-host 127.0.0.1 \
  --ledger-port 6865
```

## 10) Common pitfalls

- Using stale CIDs (consuming choices always return new CIDs)
- Running scripts without `--static-time`
- Releasing payout without house-owned sold token
- Treating vault as shared across series (it is per-series only)

## 11) Where to make changes

- Contract logic: `core/src/*.daml`
- Test scenarios: `tests/src/Test/Main.daml`
- Integration/flow guidance: `docs/*`
