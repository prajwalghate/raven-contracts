# Noob Developer Guide: Raven Hybrid Contracts + DAML Basics

This guide is for a developer with little/no DAML background.

If you read this once and run the tests, you should be able to start coding safely.

## 1. DAML Basics You Need

## 1.1 What is a template?

A DAML `template` is a contract type.

Think: SQL table row + allowed actions.

Each live contract instance has a unique CID (`ContractId <TemplateName>`).

## 1.2 What is a CID?

`CID` means Contract ID.

- It is the unique on-ledger pointer to one active contract instance.
- If a contract is consumed (archived) by a choice, that CID is dead forever.
- A new contract means a new CID.

Example:

- `vaultCid : ContractId CollateralVault`
- `tokenCid : ContractId OptionToken`

Why this matters for backend:

- You must persist new CIDs after each consuming choice.
- Using stale CIDs causes command failure (`contract not active`).

## 1.3 Signatory vs Observer

- `signatory`: party whose authority is required for contract lifecycle.
- `observer`: party that can see contract data but does not sign creation.

In this project:

- `operator` is signatory for core contracts.
- `house`, `oracle`, token `owner` are observers where needed.

## 1.4 Choices

A `choice` is an action callable on a contract.

Common pattern in our code:

- consuming choice on old CID
- create updated contract(s)
- return new CID(s)

## 1.5 Create / Fetch / Exercise / Archive

- `create T with ...` -> creates contract `T`, returns new CID.
- `fetch cid` -> reads contract data by CID.
- `exercise cid Choice with ...` -> runs a choice.
- `archive cid` -> explicitly consume contract.

## 1.6 Script tests

Daml Script (`tests/src/Test/Main.daml`) is used to simulate parties and full workflows.

- `submit party do ...` sends commands as a party.
- `submitMustFail party do ...` asserts expected failure.

## 2. Project Structure

- `core/src/Types.daml`
  - shared enums and settlement payload type
- `core/src/Series.daml`
  - OptionSeries lifecycle and oracle settlement
- `core/src/OptionToken.daml`
  - user token ownership contracts
- `core/src/Vault.daml`
  - collateral logic, minting, payouts, settlement closure
- `tests/src/Test/Main.daml`
  - happy-path + negative-path tests

## 3. Core Types Explained

From `Types.daml`:

- `OptionSide = Call | Put`
- `Cadence = Daily | Weekly`
- `SeriesStatus = Upcoming | Active | Ended | Settled | Invalidated`
- `SettlementOutcome { resolvedPrice, winningSide }`

This keeps business enums centralized and consistent across modules.

## 4. OptionSeries Contract (Series.daml)

Purpose: canonical series metadata and settlement state.

Key fields:

- `seriesRef`: your backend/business id for the series
- `underlying`, `strikePrice`
- `startTime`, `endTime`, `expiryTime`
- `status`
- `settlement : Optional SettlementOutcome`

Invariant (`ensure`):

- `strikePrice > 0`
- `start < end < expiry`

Key choices:

- `Activate` (operator)
  - allowed only after `startTime`
  - status must be `Upcoming`
- `EndTrading` (operator)
  - allowed only after `endTime`
  - status must be `Active`
- `SubmitSettlement` (oracle)
  - allowed if series ended or wall-clock >= endTime
  - computes winner rule:
    - `resolvedPrice > strikePrice => Call`
    - else `Put`
  - produces new `OptionSeries` with status `Settled`
- `Invalidate` (operator)
  - emergency path before settlement

Backend implication:

- Store latest `OptionSeries` CID whenever lifecycle choices are exercised.

## 5. OptionToken Contract (OptionToken.daml)

Purpose: ledger-backed ownership of CALL/PUT quantity.

Fields:

- `seriesRef`, `side`, `owner`, `quantity`

Choices:

- `Transfer` (owner)
  - move full quantity to `newOwner`
- `Split` (owner)
  - split one position into two CIDs (used for partial sell)
- `SettleWinner` (operator)
  - marker choice used in atomic settlement flow
- `SettleLoser` (operator)
  - marker choice used in atomic settlement flow

Also in this module:

- `CCPayout`
  - payout entitlement record (`recipient`, `amount`, `reason`)
  - can be indexed by backend for transfer processing

CID reality during partial sell:

1. User has `tokenCid(quantity=10)`.
2. User `Split(5)` -> returns two new CIDs: 5 and 5.
3. One CID transferred to house.
4. Remaining CID stays with user.

If backend still uses old 10-qty CID, the command fails because it was consumed.

## 6. CollateralVault Contract (Vault.daml)

Purpose: escrow for CC collateral and authority for mint/payout/settlement.

Fields:

- `ccReserve`: current escrow balance in model units
- `totalSetsMinted`: running total of complete sets minted
- `settlementDone`: guard against double settlement

## 6.1 `MintCompleteSets`

Input:

- `trader`, `desiredSide`, `quantity`, `depositAmount`

Checks:

- not settled
- quantity/deposit positive
- `depositAmount >= quantity` (1 CC per complete set)

Effects:

- creates trader `OptionToken` for desired side
- creates house `OptionToken` for opposite side
- creates updated vault with increased reserve and minted count

Returned CIDs:

- new vault CID
- trader token CID
- house opposite-side token CID

## 6.2 `ReleasePayout`

Purpose: release sell/swap payout from escrow.

Checks:

- not settled
- positive amount
- reserve stays non-negative
- reserve floor maintained: `remainingReserve >= totalSetsMinted`

Effects:

- creates `CCPayout` for trader
- creates updated vault with reduced reserve

Why reserve floor exists:

- You cannot drain collateral below required set backing before settlement.

## 6.3 `SettleAndPay`

Purpose: atomic settlement finalization.

Input:

- settled series CID
- all winner token CIDs
- all loser token CIDs

Checks:

- no duplicate token CIDs in lists
- series matches `seriesRef`
- series status is `Settled`
- side consistency for each winner/loser token
- winner qty sum == `totalSetsMinted`
- loser qty sum == `totalSetsMinted`
- reserve covers external winner payouts

Effects:

- consumes all winner/loser token contracts
- creates `CCPayout` for non-house winning holders
- archives settled `OptionSeries`
- creates `SeriesSettlementRecord`

Returned:

- settlement record CID
- list of created winner payout CIDs

Note:

- House-owned winning tokens are counted but not paid via external payout contracts.

## 7. End-to-End Flow Mapping

## 7.1 BUY flow (hybrid)

Off-chain:

- AMM quote computed in backend.

On-ledger:

1. operator exercises `MintCompleteSets` on vault.
2. trader receives desired side token CID.
3. house receives opposite side token CID.
4. backend stores returned CIDs and transaction id.

## 7.2 SELL flow (hybrid)

Off-chain:

- AMM payout computed in backend.

On-ledger:

1. user optionally `Split` token for partial size.
2. user `Transfer` sold token CID to house.
3. operator `ReleasePayout` from vault.
4. backend stores new vault CID + payout CID + tx id.

## 7.3 Settlement flow (hybrid)

1. oracle submits final price via `SubmitSettlement`.
2. backend determines complete winner/loser CID lists.
3. operator calls `SettleAndPay` once.
4. settlement record and payout contracts become audit source.

## 8. Tests: What Exactly Is Covered

In `tests/src/Test/Main.daml`:

- `testHybridLifecycle`
  - creates parties
  - creates active series and vault
  - mint flow for Alice
  - partial sell flow (`Split` + `Transfer` + `ReleasePayout`)
  - second mint flow for Bob
  - oracle settlement
  - full atomic settle with winner/loser CID lists
  - asserts payout and settlement accounting

- `testNegativeChecks`
  - unauthorized mint attempt fails
  - premature settlement fails
  - over-payout from reserve fails

## 9. How to Run as Developer

From repo root:

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts
dpm build --all
```

Run tests:

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests
dpm test
```

Core DAR for node upload:

- `/Users/prajwalghate/Documents/Work/canton/raven-contracts/core/.daml/dist/raven-contracts-0.2.1.dar`

## 10. Common Mistakes (and Fixes)

- Mistake: reuse old CID after consuming choice.
  - Fix: always persist returned replacement CID(s).

- Mistake: pass incomplete winner/loser token list at settlement.
  - Fix: include all active series tokens exactly once.

- Mistake: try payout that violates reserve floor.
  - Fix: check vault balance constraints before command.

- Mistake: settle before allowed time/state.
  - Fix: ensure series lifecycle transition is correct first.

## 11. Suggested Backend Tables

Minimal mapping table example:

- `series_contracts(series_id, option_series_cid, vault_cid, updated_at)`
- `position_contracts(position_id, token_cid, side, quantity, updated_at)`
- `ledger_events(local_entity, local_id, daml_tx_id, command_name, created_at)`

Without CID mapping, you will lose command continuity.

## 12. Next Learning Steps for New Dev

1. Read `core/src/Vault.daml` fully and follow each assert.
2. Run `dpm test`, then break one assert intentionally and rerun.
3. Add one new negative test in `tests/src/Test/Main.daml`.
4. Trace how CIDs change in one buy + sell path.
