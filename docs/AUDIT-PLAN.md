# Raven Contracts Audit Plan (Contracts-Only)

## 1. Context and Scope

**Purpose:** Provide a complete audit plan for Raven DAML contracts, covering architecture review, threat model, and comprehensive test matrix (unit, functional, negative, stress, economic/solvency, regression).

**In scope:**
- `core/src/Series.daml`
- `core/src/Vault.daml`
- `core/src/OptionToken.daml`
- `core/src/Types.daml`

**Out of scope:**
- Backend services, DB, infra, monitoring, node ops
- External DAR implementations (Splice) beyond interface usage
- Off-chain AMM pricing and seed computation (covered in internal audit doc but not contract scope)
- Idempotency/reconciliation behaviors (backend-owned; recorded for context only)

## 2. Architecture Review

**Contract graph:**
- `OptionSeries` (series lifecycle + settlement)
- `SeriesOracle` (on-ledger resolved price source)
- `CollateralVault` (reserve + mint/payout/settlement + seed liquidity)
- `OptionToken` (positions)
- `CCPayout` (payout entitlement)
- `PositionLot` / `PositionLotEvent` (original quantity + event timeline)
- `ActivityAudit` (reason/memo/context audit)

**State transitions and CIDs:**
- Consuming choices return new CIDs; old CIDs must not be reused.
- Vault and series are replaced on each state mutation.

**Party roles:**
- `operator`: vault authority, mint/payout/seed/settle
- `oracle`: settlement submission
- `house`: treasury inventory for opposite-side tokens
- `trader`: user/position owner
- `featured app provider`: via `featuredAppRightCid` (optional)

**Seed liquidity accounting:**
- `initialSeedLiquidity` set at vault creation
- `AddSeedLiquidity` increases `additionalSeedLiquidity`
- `RemoveSeedLiquidity` reduces only additional seed
- Reserve must remain above `totalSetsMinted` and seeded floor

**Settlement and payout model:**
- Settlement is atomic via `SettleAndPay`
- Winner payouts created only for non-house winners
- `SeriesSettlementRecord` captures final accounting

**Inputs from internal audit doc (contracts-only extraction):**
- Seed and reserve integrity (no virtual seed; reserve equals minted sets where applicable)
- ReleasePayout must enforce sold token ownership by house and series match
- Settlement must reject duplicates and pay only external winners
- CID replacement model must be respected (stale CIDs fail)
- SeriesSettlementRecord must be immutable
- PositionLotEvent chain integrity across mint/sell/settle

## 3. Trust Boundaries and Threat Model

**Trust boundaries:**
- Off-chain pricing and user cash movements are not verified on-chain.
- On-ledger checks must prevent invalid mint/payout/settlement calls.

**Key threats:**
- Unauthorized mint/settle/payout
- Unauthorized oracle price update
- Collateral drain below floor
- Double settlement or double payout
- Token list manipulation during settlement
- Seed withdrawal beyond allowed bounds
- Forged/mismatched featured app right usage
- Metadata manipulation (reason/memo/context)

## 4. Audit Baseline Controls (Referenced)

**Reference sources (audited codebase):**
- Splice release notes: `docs/src/release_notes.rst` (Quantstamp audit references)
  - Quantstamp audit reference: `CIP-0057` abstract
  - Example: mentions fixes and suggestions in release notes

**Relevant CIPs:**
- CIP-0047: Featured App Activity Markers
- CIP-0056: Token Standard (metadata conventions)
- CIP-0057: Audit reference

**Mapping to Raven checks:**
- **CIP-0047**: Raven integrates `FeaturedAppRight_CreateActivityMarker` and validates provider party.
- **CIP-0056**: Raven metadata keys follow Token Standard conventions for extensibility.
- **CIP-0057**: Raven audit artifacts (`ActivityAudit`, `PositionLotEvent`) provide on-ledger traceability.

## 5. Test Matrix (Contracts)

Each test should capture:
- Objective
- Contract(s) involved
- Inputs
- Expected outcomes
- Evidence (script logs, tx trees, state snapshots)

### 5.1 Unit Tests

| ID | Objective | Contract(s) | Inputs | Expected Outcomes | Evidence |
|----|-----------|-------------|--------|-------------------|----------|
| U-01 | Series activate lifecycle | `OptionSeries` | Start before/after startTime | Activate only after startTime | Script logs, tx tree |
| U-02 | Series end trading | `OptionSeries` | End before/after endTime | End only after endTime | Script logs |
| U-03 | Settlement submission | `OptionSeries` | Oracle submits | Settled status, winning side | Script logs |
| U-04 | Token split invariants | `OptionToken` | splitQty <= 0 or >= qty | Reject invalid splits | Script logs |
| U-05 | Vault reserve checks | `CollateralVault` | payout amounts | Enforce reserve floor | Script logs |
| U-06 | Seed add/remove bounds | `CollateralVault` | add/remove amounts | Additional seed tracking and limits enforced | Script logs |
| U-07 | ReleasePayout token ownership | `CollateralVault` | soldTokenCid owned by house | Enforced via assert | Script logs |
| U-08 | ReleasePayout series match | `CollateralVault` | soldTokenCid from other series | Reject | Script logs |
| U-09 | SettleAndPay duplicate lists | `CollateralVault` | duplicate winner/loser CIDs | Reject | Script logs |
| U-10 | Oracle update authorization | `SeriesOracle` | UpdatePrice by non-oracle | Reject | Script logs |
| U-11 | Oracle-series match | `OptionSeries` | SubmitSettlement with mismatched SeriesOracle | Reject | Script logs |

### 5.2 Functional Tests

| ID | Objective | Contract(s) | Inputs | Expected Outcomes | Evidence |
|----|-----------|-------------|--------|-------------------|----------|
| F-01 | Buy flow | `CollateralVault`, `OptionToken` | MintCompleteSets | New vault + trader/house tokens | Script logs |
| F-02 | Sell flow | `OptionToken`, `CollateralVault` | Split/Transfer + ReleasePayout | CCPayout created, reserve reduced | Script logs |
| F-03 | Settlement flow | `OptionSeries`, `CollateralVault` | SubmitSettlement + SettleAndPay | Settlement record + payouts | Script logs |
| F-04 | Seed add/remove flow | `CollateralVault` | AddSeedLiquidity, RemoveSeedLiquidity | Reserve + seed tracking updated | Script logs |
| F-05 | Lot records | `PositionLot`, `PositionLotEvent` | Mint + sell + settle | Proper lot events emitted | Script logs |
| F-06 | House seed mint (optional) | `CollateralVault`, `OptionToken` | MintCompleteSets(trader=house) | House receives both sides, vault updates | Script logs |
| F-07 | SeriesSettlementRecord immutability | `SeriesSettlementRecord` | Read after settlement | Record exists; no party can archive | Script logs |
| F-08 | Vault CID rollover | `CollateralVault` | multiple consuming choices | Old CIDs archived, new CIDs returned | Script logs |

### 5.3 Negative Tests

| ID | Objective | Contract(s) | Inputs | Expected Outcomes | Evidence |
|----|-----------|-------------|--------|-------------------|----------|
| N-01 | Non-operator mint | `CollateralVault` | MintCompleteSets by trader | Reject | Script logs |
| N-02 | Non-oracle settlement | `OptionSeries` | SubmitSettlement by non-oracle | Reject | Script logs |
| N-03 | ReleasePayout wrong token | `CollateralVault` | soldToken not house-owned | Reject | Script logs |
| N-04 | Remove too much seed | `CollateralVault` | amount > additionalSeed | Reject | Script logs |
| N-05 | Duplicate settlement CIDs | `CollateralVault` | winner list with dup | Reject | Script logs |
| N-06 | Stale vault CID | `CollateralVault` | consume old vault CID | Ledger rejects | Script logs |
| N-07 | Token from different series | `CollateralVault` | soldTokenCid from other series | Reject | Script logs |
| N-08 | Sell after settlement | `CollateralVault` | ReleasePayout after settlement | Reject | Script logs |
| N-09 | Split exceeds holding | `OptionToken` | splitQty > qty | Reject | Script logs |

### 5.4 Economic / Solvency

| ID | Objective | Contract(s) | Inputs | Expected Outcomes | Evidence |
|----|-----------|-------------|--------|-------------------|----------|
| E-01 | Reserve floor | `CollateralVault` | payout > reserve floor | Reject | Script logs |
| E-02 | Payout totals | `CollateralVault` | settlement winners | total payout == external winners | Tx tree |
| E-03 | House-only winners | `CollateralVault` | all winners = house | 0 external payouts | Script logs |
| E-04 | Settlement accounting | `CollateralVault` | winners/losers qty vs totalSetsMinted | Reject if mismatch | Script logs |

### 5.5 Stress & Scale

| ID | Objective | Contract(s) | Inputs | Expected Outcomes | Evidence |
|----|-----------|-------------|--------|-------------------|----------|
| S-01 | Large token list | `CollateralVault` | Many winner/loser CIDs | Settlement succeeds within limits | Script logs |
| S-02 | Many lot events | `PositionLotEvent` | Many trades | No invariant breaks | Script logs |
| S-03 | Large settlement lists | `CollateralVault` | 100+ winner/loser CIDs | No duplicate/mismatch allowed | Script logs |

### 5.6 Regression / Upgrade

| ID | Objective | Contract(s) | Inputs | Expected Outcomes | Evidence |
|----|-----------|-------------|--------|-------------------|----------|
| R-01 | Backward compat | `CollateralVault` | use old DAR data if needed | No break in state | Manual review |
| R-02 | New fields | `OptionToken`, `Vault` | new optional fields | Defaults behave correctly | Script logs |

## 6. Evidence and Reporting

**Required outputs:**
- Script/test logs
- Transaction tree summaries for key flows
- Manual mapping of test cases to requirements
- Stale-CID rejection evidence (at least one test)
- PositionLotEvent chain integrity evidence (mint → sell → settle)
 - Internal audit traceability table (DAR/TOK coverage)

**Acceptance checklist:**
- All tests green
- Invariants validated (reserve floor, settlement totals)
- No unresolved critical findings
 - All contract-only inputs from internal audit doc addressed

## 7. Sign-off Criteria

- All contract tests green
- All negative cases explicitly verified
- All financial invariants validated
- Audit artifacts complete and documented

## 8. References

- Splice release notes (Quantstamp audit references):
  `/Users/prajwalghate/Documents/Work/canton/splice/docs/src/release_notes.rst`
- CIP-0047: https://github.com/global-synchronizer-foundation/cips/blob/main/cip-0047/cip-0047.md
- CIP-0056: https://github.com/global-synchronizer-foundation/cips/blob/main/cip-0056/cip-0056.md
- CIP-0057: https://github.com/global-synchronizer-foundation/cips/blob/main/cip-0057/cip-0057.md#abstract
- Raven Contract Spec: `docs/CONTRACT-SPEC.md`
- Raven Functionality and Flow: `docs/FUNCTIONALITY-FLOW.md`

## 9. Internal Audit Traceability (Contracts Only)

This section ensures no expected contract result from the internal audit doc is missed.

| Internal ID | Covered by | Notes |
|-------------|------------|-------|
| DAR-01 | F-06 | House seed mint with full backing |
| DAR-02 | E-01 + U-06 | Reserve equals minted sets at init (seed integrity) |
| DAR-03 | F-01 | MintCompleteSets increments totals and reserve |
| DAR-04 | F-02 | ReleasePayout reduces reserve and archives old vault |
| DAR-05 | E-01 | Reserve floor enforcement on sell |
| DAR-06 | N-08 | Cannot sell after settlement |
| DAR-07 | U-03 | SubmitSettlement locks series |
| DAR-08 | F-03 | SettleAndPay correct winners/losers |
| DAR-09 | E-03 | Only external winners get payout |
| DAR-10 | F-07 | SeriesSettlementRecord immutability |
| TOK-01 | U-04 | Split exact quantity success |
| TOK-02 | N-09 | Split exceeds holding rejected |
| TOK-03 | U-07 | Sold token must be house-owned before payout |
| TOK-04 | U-08 | Sold token must belong to same series |
| TOK-05 | N-06 | Stale vault CID rejected |
| TOK-06 | F-05 | PositionLotEvent chain integrity |
| TOK-07 | N-06 | Double sell attempt (archived CID rejected) |
