# A/B Frozen real ledger migration analysis

Status: read-only source analysis plus a standalone dry-run prototype; no customer ledger file was loaded, decoded, or changed. A/B archives and source trees remain Frozen.

## Source model evidence

A source: `references/A-FROZEN/GuanpanNext/ios/Sources/NextCore.swift` and `NextAppModel.swift`, pinned to A Frozen HEAD `eb6fa384a2df8c503eb76d13f68d080c08be31ad`.

B source: `references/B-FROZEN/guanpan-pro-native/Sources/NextCore.swift`, `NextAppModel.swift`, and `NextAppModelState.swift`, pinned to B Frozen HEAD `9ddfe32b787ad9e522a48eb55ff8231227d79599`.

Both use a `NextAuditedBook` wrapper containing `current: NextBook` and `events: [NextAuditEvent]`. B's local account filename is `real-ledger-v1.json`. `NextBook` has schemaVersion, id, cash, positions, fills, cashMovements, incomeEvents, dividendEvents, history, and importedAt. A and B define the same economic field groups; B adds stronger structural/time/identity checks and safe repository handling. This is model compatibility evidence, not proof that an actual account file exists or validates.

## Field mapping and loss boundaries

| Legacy fact | A/B representation | F representation | Dry-run handling |
|---|---|---|---|
| Account identity | `NextBook.id: UUID` | `FAccountBook.accountID` | Preserve source ID in migration provenance; do not silently treat it as F ID until deterministic mapping is specified. |
| Current cash | `cash: Decimal` | opening cash + current cash | Map current cash to an opening snapshot only after finite/nonnegative checks. |
| Current positions | code/name, `units: Int`, `bookCost: Decimal`, optional acquiredAt; legacy may allow zero units | positive `Int64` positions with stable UUID | Reject overflow, invalid codes, duplicate codes, negative values; zero-unit rows become report-only source evidence, never active F positions. |
| Fills | UUID, date, code, side string, Int units, Decimal price/fee/realized | sequence, enum side, Int64 units, confirmation metadata, explicit sell cost basis; realized profit not yet modeled | Preserve exact raw fill bytes/evidence. Do not synthesize event sequence, user-confirmation evidence, or cost-basis removal. Flag history as not replayable into F events. |
| Cash movements | UUID, date, amount, reason | sequence plus explicit user confirmation | Preserve source records as evidence; do not invent sequence or confirmation metadata. |
| Audit history | before/after full `NextBook` snapshots, action/reason/time; B validates IDs/timestamps and snapshots | compact digest audit events | Preserve original audit chain in migration provenance; do not reduce it to F audit events without an explicit loss report. |
| Income/dividend events | expected/received income and dividend reference data | no matching F ledger fields | Keep outside the active F ledger and report counts/values. Never discard silently. |
| Asset history | snapshots of total and externalFlow | no matching F ledger fields | Keep as source evidence; do not reinterpret as cash movements. |
| Missing Codable fields | A/B custom decoder defaults several fields; UUID defaults can be generated during decode | F requires explicit validated values | Dry-run parser must distinguish absent, null, malformed, and explicit zero; it must not invoke legacy defaulting decoders. |

## Accounting interpretation

A/B `NextBook.validate()` is principally structural. It does not prove that current cash/positions reconcile to fills and cash movements, and the stored `realized` field is not enough to recover F's required weighted-average sale cost basis. Timestamps may tie and legacy records do not have a global ledger sequence. A/B audit snapshots may include edits, undo operations, imports, or manual balance corrections that cannot safely be inferred as broker-confirmed fills.

Therefore, the first migration design must treat the legacy current cash and positive positions as a candidate F opening snapshot at an explicit migration capture time. Historical fills, cash movements, audits, income, dividends, and asset history remain immutable source evidence attached to the migration report/provenance; none are replayed as new F transactions unless a future, separately validated mapping can prove the required facts. The report must state this boundary and all counts/totals. Missing or inconsistent current-state data blocks the candidate rather than being repaired silently.

## Required migration protocol

1. Read bytes without writing to the source. Record source kind (A/B), exact byte length, SHA-256, schema version, account ID, and a stable idempotency key derived from source identity plus content hash.
2. Parse without legacy model defaults. Produce explicit diagnostics for missing/null/invalid fields, duplicates, integer overflow, unsupported versions, invalid dates, and unrecognized event sides.
3. Produce a dry-run report and candidate opening snapshot only. No `FAccountBookStore.save`, account creation, or UI state update is reachable from the dry-run API.
4. Validate F opening snapshot invariants and current position/cash totals. Preserve original source bytes or a verified archival copy before any future commit path.
5. A later explicit import action must show the report, require a fresh user confirmation, check the expected current F digest, reject an already-recorded idempotency key, and atomically commit the F book plus migration provenance. Failure must leave the original F account bytes unchanged and be retryable without duplicate import.
6. Do not offer a commit path until tests can execute for dry-run purity, exact mapping, duplicate import rejection, idempotency, rollback, damaged sources, and ledger reconciliation.

## Current limitations

- No real account data has been supplied to this analysis; findings describe source code only. A synthetic local JSON fixture was used to exercise the dry-run preview.
- `Tools/legacy_ledger_dry_run.py` is a standalone read-only prototype. It reports byte length/SHA-256, distinguishes missing core fields, maps a candidate opening snapshot, counts but never replays legacy events, and derives deterministic target IDs/idempotency key. It has no F write path.
- `FAccountBookStore` now contains an initial-migration commit API with a typed source receipt, original source bytes in the same archive, deterministic target identity checks, duplicate-key rejection, non-empty-target refusal, explicit confirmation metadata, and the existing atomic write/read-back/rollback path. The Swift code is not compiled, and the API is not connected to a Swift typed parser or app flow; do not treat this as migration acceptance.
- F XCTest remains 30 defined / 0 executed / 0 passed / 0 failed; current cloud runtime has no Swift/Xcode toolchain.
- This analysis is not an acceptance pass for A, B, or F.
