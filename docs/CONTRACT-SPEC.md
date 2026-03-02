# Contract Spec

## Templates

## `OptionSeries`

Purpose: canonical series metadata and settlement authority.

Fields:
- `operator`, `oracle`, `house`
- `seriesRef`, `underlying`, `strikePrice`, `feeRate`, `collateralAsset`
- `startTime`, `endTime`, `expiryTime`, `cadence`
- `status`, `settlement`

Choices:
- `Activate` (operator)
- `EndTrading` (operator)
- `SubmitSettlement` (oracle): commits `resolvedPrice` and winning side
- `Invalidate` (operator)

## `OptionToken`

Purpose: on-ledger CALL/PUT position ownership.

Fields:
- `operator`, `seriesRef`, `side`, `owner`, `quantity`

Choices:
- `Transfer` (owner)
- `Split` (owner)
- `SettleWinner` (operator)
- `SettleLoser` (operator)

## `CollateralVault`

Purpose: escrow and lifecycle control for a series.

Fields:
- `operator`, `house`, `seriesRef`
- `ccReserve`
- `totalSetsMinted`
- `settlementDone`

Choices:
- `MintCompleteSets` (operator)
  - Mints desired side to trader
  - Mints opposite side to house
  - Updates reserve and `totalSetsMinted`
- `ReleasePayout` (operator)
  - Emits `CCPayout`
  - Enforces reserve floor `remainingReserve >= totalSetsMinted`
- `SettleAndPay` (operator)
  - Validates settled series
  - Validates token lists and side/series consistency
  - Archives all passed tokens
  - Creates payout contracts for non-house winning holders
  - Archives series and emits immutable settlement record

## `CCPayout`

Purpose: payout entitlement for off-chain transfer processor or future cash-token bridge.

## `SeriesSettlementRecord`

Purpose: immutable settlement event for indexers and audit.

## Invariants

- Time ordering: `startTime < endTime < expiryTime`
- Deposit floor: `depositAmount >= quantity` on mint
- Pre-settlement reserve floor: vault reserve cannot drop below `totalSetsMinted`
- Settlement accounting:
  - total winning token quantity must equal `totalSetsMinted`
  - total losing token quantity must equal `totalSetsMinted`
- Winner rule: `resolvedPrice > strikePrice` => CALL else PUT

## Backend Command Mapping

- BUY `/trade`:
  1. `MintCompleteSets`
  2. Optional `ReleasePayout` for unwanted-side swap proceeds
- SELL `/trade`:
  1. user `Transfer` (or `Split` + `Transfer`) of sold tokens to house
  2. backend `ReleasePayout`
- SETTLEMENT worker:
  1. oracle `SubmitSettlement`
  2. operator `SettleAndPay`
