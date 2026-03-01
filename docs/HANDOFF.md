# DAR Handoff Guide

## Build

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts
dpm build --all
```

## Validate Locally

```bash
cd /Users/prajwalghate/Documents/Work/canton/raven-contracts/tests
dpm test
```

## Upload Target (Node Team)

Use only the core DAR:

- `/Users/prajwalghate/Documents/Work/canton/raven-contracts/core/.daml/dist/raven-contracts-core-0.2.0.dar`

Do not upload the tests DAR in production.

## Node Team Inputs

- Core DAR file
- package name/version: `raven-contracts-core:0.2.0`
- Party mapping for `operator`, `oracle`, `house`
- backend integration doc: `docs/CONTRACT-SPEC.md`

## Operational Notes

- AMM pricing remains off-chain.
- Ledger is source of truth for option-token custody and settlement events.
- Backend must persist CIDs returned from create/exercise results.
- Settlement worker must pass complete winner/loser token CID lists.

## Recommended DB Mapping

- `option_series.id -> option_series_cid`
- `option_series.id -> collateral_vault_cid`
- `positions.id -> option_token_cid` (or CID set when split)
- `trades.id -> daml_tx_id`
