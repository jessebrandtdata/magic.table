# Design: the `magic.table` abstraction

**Status:** Draft — pending Jesse review
**Date:** 2026-06-29
**Owner:** Jesse Brandt (direction); agent (draft)

## Where this came from

Jesse's `/decisions` ruling (2026-06-29), course-correcting the provisional
`sheet_frame`:

> COURSE-CORRECT the class name — `magic.table` (dotted, mirrors `data.frame`),
> NOT `sheet_frame`. And it's a direction, not just a name: build it as an
> ABSTRACT recorded-computation primitive holding (1) column provenance (track
> edits made post-creation) and (2) an optional synced external table
> (sheets/excel/disk/db) whose external edits we want to reconcile. Sheets is
> just one export format — focus Sheets capability now but architect for the
> abstraction.

This refines `north_star.md` (Jesse's, read-only). It does **not** replace it —
it's the concrete architecture for the "magic_table" the north star describes.

## The core idea

A `magic.table` is a data frame that **remembers what was done to it**. Wrapping
a data frame with `magic.table(df)` starts a recording: from then on, operations
(today `mutate()`) are stored as *unevaluated computations*, not collapsed to
values. That recording is the asset. It can be:

- **exported** to an external table where the computations become live formulas
  (Google Sheets today), and
- **reconciled** later against external edits to that table.

`data.frame` is the mental model for the name and feel; the twist is that a
`magic.table` is lazy and provenance-aware.

## Two things it holds

### 1. Column provenance (recorded computation)

Every column added after creation is stored as the expression that produced it,
in order. Today that lives in `ops` (a list of `mutate` ops, each a named list
of quosures). Provenance answers, per column: *original data, or derived — and
if derived, from what expression?*

This is already the mechanism behind the formula export: `as_sheet_cells()`
walks `ops` and translates each expression to an A1 formula. The same record is
what a future `provenance(mt)` accessor would surface to the user, and what
reconciliation (below) diffs against.

**Open design question (Q1):** how rich should provenance be? Minimum = the
ordered `ops` we already keep. Richer = a per-column record (`origin =
"source" | "computed"`, the source expression, the op index, dependencies on
other columns). The richer form is what makes "explain this column" and
"recompute downstream" possible. Recommended: ship the minimal `ops` record now,
add a `provenance()` accessor that *derives* the per-column view on demand
(no new stored state), and only promote it to stored state if a feature needs it.

### 2. Optional synced external table (the `backend`)

A `magic.table` may be **bound** to an external table it writes to and reconciles
against. The binding is a small piece of data carried on the object (`backend`,
`NULL` until synced) describing *where* the table lives and *how* to talk to it:

```
backend = list(
  type   = "gsheet",          # "gsheet" | "excel" | "disk" | "db" (future)
  handle = <ss + sheet + start_row>,  # what range_write needs, today
  synced_at = <timestamp/etag>        # for change detection (future)
)
```

Backends are an open set. **Sheets is the only one built now.** The core
(`R/magic_table.R`) stays backend-agnostic; each backend is a module that knows
how to (a) render the recorded computations into that format's formula dialect
and (b) read the external state back for reconciliation. Today's
`R/write_sheet.R` (`as_sheet_cells()` + `write_sheet()` + the dialect in
`R/dialect.R`/`R/translate.R`) **is** the gsheet backend; it just isn't named as
a formal interface yet.

**Open design question (Q2):** reconciliation semantics. The north star says
"poll the gsheet to see if it has changed and … warn and by default not
overwrite." Concretely, when the external table has diverged from the recorded
computation, the default `write_sheet()` should: (a) detect divergence (compare
a stored etag/snapshot against the live sheet), (b) **refuse to overwrite** and
warn, (c) offer an explicit `overwrite = TRUE` / a reconcile path. Recommended
default: **no-clobber + warn**, opt-in overwrite. This is unbuilt — flagged for
Jesse before implementation, since "don't silently destroy a user's sheet" is a
stakes decision.

## What is built now (this PR)

- `magic.table(df)` constructor + class `magic.table` (mirrors `data.frame`).
- `print.magic.table` (schema, recorded-op count, backend status).
- `mutate.magic.table()` — records computations as column provenance.
- The **gsheet backend**: `as_sheet_cells()` (pure, auth-free), `write_sheet()`,
  and an extensible R→Sheets dialect (`register_sheet_translator()` /
  `sheet_translators()`).
- `backend` slot present on the object but always `NULL` (seam only — no sync,
  no reconciliation yet).

All correctness is exercised through the pure `as_sheet_cells()`; no live-Sheets
test. Legacy eager helpers (`write_analytical_table`, `make_summary_row`,
`col_letter`) are untouched.

## What is deliberately deferred (later waves)

1. **`provenance()` accessor** + richer per-column provenance (Q1).
2. **Backend binding + sync state** — populate `backend`, store an etag/snapshot
   at write time.
3. **Reconciliation / change-polling** — detect external edits, no-clobber +
   warn by default, opt-in overwrite (Q2).
4. **Additional backends** — Excel, on-disk (csv/parquet), database. Each reuses
   the recorded-computation core and supplies its own formula dialect + readback.
5. **The R-function-reference branch of the north star** — columns whose
   computation is *an R closure* rather than a spreadsheet formula (default to a
   separate sheet, etc.). Out of scope here; it's the second half of the vision.

## Open design question: inherit from tibble, or wrap it?

`north_star.md` says a magic.table is "a reusable table object **based on
tibble**" and earlier asks "(but like should we inherit from tibble)". Two
shapes:

- **Wrap (current):** `magic.table` is a list `{data, ops, backend}` with class
  `c("magic.table", "tbl")`. The recorded-computation state is cleanly separate
  from the data; the object is *not* itself a tibble.
- **Inherit:** `magic.table` *is* a tibble (subclass) carrying `ops`/`backend`
  as attributes. It would print and behave like a tibble in more contexts, at
  the cost of threading the recorded state through tibble's `[`/`[[`/`mutate`
  machinery without losing it.

**Open design question (Q4):** wrap vs inherit. The wrap form is simpler and is
what's built; "based on tibble" leans toward inherit. Recommended: keep the wrap
now (it isolates provenance state and is easy to reason about), revisit inherit
if/when users want a magic.table to drop transparently into tibble-expecting
code. Reversible — the public surface (`magic.table()`, `mutate`, `write_sheet`)
doesn't change either way.

## Naming notes

- Class + constructor: `magic.table` / `magic.table(df)` — mirrors `data.frame` /
  `data.frame()` (Jesse's call). Constructor as a plain `magic.table()` (not
  `as.magic.table()`) avoids the `as.<generic>` S3-method-name footgun while
  reading as a faithful `data.frame()` mirror. **Reversible — flagged in the PR**
  in case Jesse prefers an `as.magic.table()` coercer.
- The gsheet backend keeps Sheets-y names (`write_sheet`, `as_sheet_cells`) since
  they are Sheets-specific; a future backend gets its own verbs.

## Open questions for Jesse

- **Q1 — provenance richness:** minimal `ops` record + derived accessor now, or
  a stored per-column provenance structure from the start? (Recommend: minimal.)
- **Q2 — reconciliation default:** confirm no-clobber + warn, opt-in overwrite,
  as the default when the external table has diverged. (Recommend: yes.)
- **Q3 — constructor form:** `magic.table(df)` (current) vs an `as.magic.table()`
  coercer. (Recommend: keep `magic.table(df)`.)
- **Q4 — wrap vs inherit from tibble:** keep the wrap, or make `magic.table` a
  tibble subclass? (Recommend: keep the wrap for now.)
