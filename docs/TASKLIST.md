# Task List

## Completed

- [x] Created isolated DAML project: `/Users/prajwalghate/Documents/Work/canton/raven-contracts`
- [x] Implemented simplified hybrid templates (`OptionSeries`, `CollateralVault`, `OptionToken`)
- [x] Added settlement artifacts (`CCPayout`, `SeriesSettlementRecord`)
- [x] Added end-to-end and negative Daml Script tests
- [x] Split production/test packages (`core` + `tests`)
- [x] Built with `dpm build --all`
- [x] Tested with `dpm test` in `tests` package
- [x] Generated production DAR (`raven-contracts-core-0.2.0.dar`)
- [x] Added handoff and noob-learning docs

## Next

- [ ] Add backend table migration for CID mapping and command idempotency keys
- [ ] Add operator runbook for scheduled `Activate`, `EndTrading`, `SubmitSettlement`
- [ ] Add settlement chunking strategy for high-holder series
- [ ] Add authorization whitelist templates (optional v2)
