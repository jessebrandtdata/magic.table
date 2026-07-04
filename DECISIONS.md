# Decision log

Design- and model-affecting choices for this project, from **2026-06-29** forward.
Reversible choices are EXECUTE-and-logged by agents; substantive ones are routed
through `dq` → `/decisions` and recorded here on resolution. This file is the
permanent, inspectable record of *why this project is shaped the way it is*.

**Provenance note:** anything in this repo predating this log is **unattributed and
not settled** — it may be Jesse's choice or an agent's, reviewed or not. `north_star.md`
(if present) is Jesse's, as of its date. Agents: do not cite pre-log code or structure
as "already decided" — promote load-bearing pre-log choices through `dq` (substantive)
or `dlog` (reversible) before building on them.
See `~/workspace/docs/decision-log.md` for the convention.

---

## 2026-06-29 — Class name: sheet_frame (provisional, building under it)
- **Choice:** Use S3 class 'sheet_frame' + constructor 'as_sheet_frame' for the lazy formula-table, per the 2026-05-19 spec, pending Jesse's call on the public name (queued in dq).
- **Why:** north_star marked 'magic_table' as provisional ('for the moment'); sheet_frame is descriptive and already specced. Renaming an S3 class + constructor is a mechanical reversible refactor.
- **Reversible:** yes · **Decided by:** agent

## 2026-06-29 — Wave 1 scope: implement the formula branch (lazy sheet_frame + mutate)
- **Choice:** First wave = the lazy sheet_frame + dplyr::mutate -> A1 formula translator (per the 2026-05-19 spec). Deferred to later waves: the R-function-reference (closure-computed) column branch, multi-sheet placement of derived columns, the stored gsheet connection object, and change-polling / no-clobber-on-overwrite.
- **Why:** north_star describes a larger magic_table vision; the formula branch is the concrete, already-specced, independently-evaluable slice. Shipping it first proves the lazy-frame core that the other branches build on. Scope is additive/reversible — later waves extend, they don't undo this.
- **Reversible:** yes · **Decided by:** agent

## 2026-06-29 — magic.table class name + direction
- **Choice:** magic.table (mirrors data.frame); abstract recorded-computation primitive with column provenance + optional synced external table (sheets/excel/disk/db); Sheets first, architect for abstraction
- **Why:** Jesse: sheets is just one export format; the value is recorded computations + provenance + external-edit sync, worth building as a primitive even if it re-treads dplyr
- **Reversible:** yes · **Decided by:** jesse

## 2026-06-29 — RESOLVED: class is magic.table (Jesse, /decisions) — abstract recorded-computation primitive
- **Choice:** Class renamed sheet_frame -> magic.table (dotted, mirrors data.frame). Constructor: magic.table(df) (mirrors data.frame() directly; avoids the as.<generic> S3 footgun). It is an ABSTRACT recorded-computation primitive holding (1) column provenance (post-creation edits) and (2) an optional synced external table (sheets/excel/disk/db) to reconcile against external edits. Sheets is one export backend — built now; architect for the abstraction.
- **Why:** Jesse's call from the /decisions drain (his taste + product direction; supersedes the provisional sheet_frame). Constructor form magic.table() is the faithful data.frame() mirror.
- **Reversible:** no · **Decided by:** agent

## 2026-06-29 — Track docs/superpowers/ design records (narrow the docs/ gitignore)
- **Choice:** Narrowed the .gitignore 'docs/' rule to '/docs/*' + '!/docs/superpowers/' so pkgdown's generated site stays ignored but the docs/superpowers/ specs+plans are tracked. Committed the existing 2026-05-19 mutate-to-sheets spec/plan and the new 2026-06-29 magic.table abstraction design.
- **Why:** The broad 'docs/' ignore (for pkgdown output) also hid the design record. Jesse reviews on a different machine, so a gitignored design doc is invisible to him; tracking docs/superpowers/ makes the design reviewable in the PR. .Rbuildignore already excludes docs/superpowers from the build.
- **Reversible:** yes · **Decided by:** agent

## 2026-06-29 — magic.table architecture (Q1-Q4)
- **Choice:** Q1 minimal ops-record + derived accessor; Q2 no-clobber+warn on external divergence; Q3 export BOTH magic.table(df) constructor and as.magic.table() coercer; Q4 wrap a tibble now, revisit inherit (north_star 'based on tibble' leans inherit later)
- **Why:** Q1/Q2 reversible defaults (safe-by-default sync); Q3/Q4 Jesse's API-surface + architecture calls
- **Reversible:** yes · **Decided by:** jesse

## 2026-07-06 — Verify formulas by hand-paste BEFORE the public rename (Jesse)
- **Choice:** Before the GsheetGenie -> magic.table rename/public work, ship a
  no-auth verification artifact: `verification/make-demo.R` builds a magic.table
  from `head(mtcars)`, records lazy mutate columns (arithmetic + a mean-based
  ratio via a registered `mean` translator) and a summary row, materializes the
  A1 grid, and emits `verification/demo-paste.tsv` (paste at cell A1) plus
  `verification/PASTE-ME.md` with steps + eagerly-computed expected values. The
  rename work proceeds only after Jesse's paste test passes.
- **Why:** Jesse (2026-07-06 chat) wants to confirm the offline expression->A1
  translation actually evaluates correctly in a real sheet before investing in
  the public relaunch. Verification-first de-risks the showpiece.
- **Reversible:** yes · **Decided by:** jesse

## 2026-07-06 — openxlsx is the working Excel export backend (agent call, Jesse-approved dep)
- **Choice:** openxlsx replaces the parked googlesheets4 live-write as the working,
  token-free export backend: it writes real `=...` formulas into a local `.xlsx`
  (Excel opens directly; Google Sheets gets them via File▸Import). Jesse approved
  installing/adding openxlsx (2026-07-06). **Placement call (delegated to agent):
  openxlsx goes in `Imports`, not Suggests** — the xlsx writer will be a core
  exported selling point ("write live formulas to Excel, no auth"), and a headline
  export path shouldn't fail at runtime for a missing optional dep. openxlsx is
  well-maintained and light (Rcpp/zip/stringi, already present). Verified in the
  checkpoint via `verification/demo-formulas.xlsx` (16 embedded formulas incl.
  absolute-range AVERAGE). Package `R/` xlsx backend + DESCRIPTION change land in
  the rename phase; the offline TSV path stays dependency-light and openxlsx-free.
- **Why:** Jesse's rationale — Sheets has no token-free write API, but openxlsx +
  Import is a real, auth-free round-trip. Imports vs Suggests left to agent.
- **Reversible:** yes (Imports↔Suggests is a one-line DESCRIPTION change) · **Decided by:** agent

## 2026-06-29 — RESOLVED (Jesse, /decisions): magic.table architecture Q1–Q4
- **Choice:** Q1 provenance = minimal ops-record + derived provenance() accessor (no new stored state). Q2 reconciliation on external divergence = no-clobber + warn by default; opt-in overwrite later. Q3 constructor = export BOTH magic.table(df) AND as.magic.table() coercer. Q4 = start WRAP now (move-fast), keep the inherit-from-tibble path open for a later revisit (north_star 'based on tibble' leans inherit).
- **Why:** Jesse's /decisions answers to the 4 deferred questions. Proceed building the deferred layers (coercer, provenance accessor, sync+reconciliation) under these.
- **Reversible:** no · **Decided by:** agent

## 2026-07-04 — RESOLVED (Jesse, /decisions): launch export surface = ship all 9 as-is
- **Choice:** No trimming of the public API before launch. All 9 current exports ship: `magic.table`, `as.magic.table`, `write_sheet`, `as_sheet_cells`, `provenance`, `write_analytical_table`, `make_summary_row`, `register_sheet_translator`, `sheet_translators` (plus `col_letter`, the one utility-grade export).
- **Why:** Jesse accepted the agent's recommendation from the launch-readiness dq — each export is either core to the lazy-formula pitch or already advertised in the README, and `col_letter` is a documented composition point for `write_analytical_table`'s custom-layout path.
- **Reversible:** yes (exports are additive; a future breaking removal would need its own decision) · **Decided by:** jesse
