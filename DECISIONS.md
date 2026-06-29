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
