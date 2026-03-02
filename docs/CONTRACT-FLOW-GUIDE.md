# Contract Flow Guide

This is the exact on-ledger flow for Raven Hybrid V1.

## Contracts Involved

- `OptionSeries`
- `CollateralVault`
- `OptionToken`
- `CCPayout`
- `SeriesSettlementRecord`

## Flow 1: Series Setup

1. Operator creates `OptionSeries` with:
   - `seriesRef`, `strikePrice`, lifecycle times, `status`
   - `oracle` party (or operator for no-oracle mode)
2. Operator creates `CollateralVault` for same `seriesRef`.
3. Backend stores both CIDs.

Resulting state:

- one active series CID
- one active vault CID

## Flow 2: BUY (Mint Complete Sets)

Input:

- `trader`, `desiredSide`, `quantity`, `depositAmount`

Choice called:

- `CollateralVault.MintCompleteSets`

What happens:

1. Contract checks quantity/deposit constraints.
2. Creates trader `OptionToken` on desired side.
3. Creates house `OptionToken` on opposite side.
4. Creates new vault CID with updated reserve and minted count.

Outputs to persist:

- new `vault_cid`
- `trader_token_cid`
- `house_opposite_token_cid`

## Flow 3: SELL (Return Token + Payout)

Input:

- token CID to sell, payout amount

Choices called:

1. `OptionToken.Split` (optional partial sell)
2. `OptionToken.Transfer(newOwner = house)`
3. `CollateralVault.ReleasePayout(trader, amount, reason)`

What happens:

1. User transfers sold token to house custody.
2. Vault enforces reserve floor and creates `CCPayout`.
3. Vault rolls to new CID with reduced reserve.

Outputs to persist:

- new `vault_cid`
- `payout_cid`
- any new token CIDs from split/transfer

## Flow 4: Settlement Submit

Input:

- `resolvedPrice`

Choice called:

- `OptionSeries.SubmitSettlement`

What happens:

1. Contract validates lifecycle status/time.
2. Computes winning side:
   - `resolvedPrice > strikePrice` => CALL
   - else PUT
3. Returns new `OptionSeries` CID with `status = Settled`.

Output to persist:

- new `option_series_cid`

## Flow 5: Final Settlement (Atomic)

Input:

- `seriesCid` (settled)
- full `winningTokenCids`
- full `losingTokenCids`

Choice called:

- `CollateralVault.SettleAndPay`

What happens atomically:

1. Validates series reference and settled state.
2. Rejects duplicate CIDs.
3. Validates each token side and series.
4. Consumes winner and loser token contracts.
5. Creates `CCPayout` for non-house winning holders.
6. Archives settled series.
7. Creates `SeriesSettlementRecord`.

Outputs to persist:

- `settlement_record_cid`
- `winner_payout_cids[]`

## Critical CID Rules

- Every consuming choice invalidates old CID.
- Always replace stored CID with returned CID.
- Settlement requires complete token CID coverage; missing one fails the command.

## Minimal Sequence Example

1. Create series + vault
2. Buy CALL 10
3. Sell CALL 5
4. Submit settlement price
5. Settle and pay

This exact sequence is covered by `tests/src/Test/Main.daml:testHybridLifecycle`.
