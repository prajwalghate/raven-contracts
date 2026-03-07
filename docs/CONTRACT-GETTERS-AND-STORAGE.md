# Contract Getters and Storage Map

This document answers: what is stored on-ledger, and what your backend can fetch/query.

## How getters work in DAML

- DAML templates do not expose Solidity-style `view` getters.
- You "get" data by:
  - querying active contracts by template
  - fetching by known `ContractId`
  - reading transaction events (create/archive/exercise)

## Template storage and query usage

## `Series.OptionSeries`

Stored fields:
- `seriesRef`, `underlying`, `strikePrice`, `feeRate`, `collateralAsset`
- `startTime`, `endTime`, `expiryTime`, `cadence`
- `status`, `settlement`

Backend gets:
- active series state by latest CID
- settlement outcome from `settlement`

## `Vault.CollateralVault`

Stored fields:
- `ccReserve`
- `initialSeedLiquidity`
- `additionalSeedLiquidity`
- `totalSetsMinted`
- `settlementDone`

Backend gets:
- per-series reserve state
- seed accounting split (initial vs added)

## `OptionToken.OptionToken`

Stored fields:
- `owner`, `seriesRef`, `side`, `quantity`
- `metadata` (`externalUserId`, `userMemo`)
- `lotCid`

Backend gets:
- live user positions from active tokens
- remaining quantity by summing active token quantities

## `OptionToken.PositionLot`

Stored fields:
- `trader`, `seriesRef`, `side`
- `originalQuantity`
- `createdAt`
- `metadata`

Backend gets:
- original buy quantity per lot
- lot-level grouping key for downstream analytics

## `OptionToken.PositionLotEvent`

Stored fields:
- `lotCid`, `eventKind`, `quantity`, `tokenCid`
- `reason`, `metadata`, `choiceContext`, `markerMetadata`
- `eventTime`

Backend gets:
- lot event history (mint/sell/settlement)
- reason/memo/context traceability for each position change

## `OptionToken.CCPayout`

Stored fields:
- `recipient`, `seriesRef`, `amount`
- `reason`, `metadata`
- `sourceLotCid`

Backend gets:
- payout queue items
- payout-to-lot linkage for reconciliation

## `Vault.SeriesSettlementRecord`

Stored fields:
- `resolvedPrice`, `winningSide`
- `totalSetsMinted`
- `externalWinnerPayout`
- `houseResidual`

Backend gets:
- immutable final settlement report for one series

## `OptionToken.ActivityAudit`

Stored fields:
- `action`, `reason`
- `metadata`, `choiceContext`
- `markerMetadata`
- `eventTime`

Backend gets:
- human-readable and machine-readable action audit trail
- memo/reason/context for every major lifecycle operation

## Suggested backend getter projections

1. `getSeriesState(seriesRef)`:
- `OptionSeries` + current `CollateralVault`

2. `getUserOpenPositions(user, seriesRef)`:
- active `OptionToken` rows for user

3. `getUserLots(user, seriesRef)`:
- `PositionLot` + `PositionLotEvent` timeline

4. `getSeriesPayouts(seriesRef)`:
- `CCPayout` + status in backend settlement table

5. `getSeriesSettlementReport(seriesRef)`:
- `SeriesSettlementRecord` + related `ActivityAudit`
