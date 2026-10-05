# DECISIONS LOG

Records meaningful decisions made during the project and why.

---

## 2026-09-07 — Checkpoint 1: Requirements & Architecture Locked

All business scope, stakeholders, business questions, data architecture
(5-table star schema), KPI definitions, data-generation philosophy, and
the AI operating workflow were locked. See PROJECT_SPEC.md and
DATA_DICTIONARY.md.

---

## 2026-09-07 — Deliverable #1: Generator built, two bugs found and fixed during inspection

**Decision:** Build `python/generate_data.py` to produce the five raw
CSVs, then actually inspect the output before trusting it — the rule
here is we fix the generator, we don't patch bad data downstream.

**What we found on first inspection:**

1. **Delivery-date logic bug (fixed).** For products with very short
   lead times (1–2 days), the on-time/early delivery offset
   (`random.randint(-3, 0)`) could push `Actual_Delivery_Date` before
   `Order_Date` — physically impossible, not a deliberate data-quality
   issue. Affected 599 of ~19,300 rows before the fix. **Fix:** the
   early-delivery offset is now bounded by the product's own lead time,
   so a delivery can never be logged before the order was placed. After
   the fix, only the 13 intentionally-injected bad-date rows (~0.07%)
   show this pattern — matches the small controlled-issue target from
   PROJECT_SPEC section 15.

2. **Unrealistic line totals in Manufacturing "Components" (fixed).**
   Unit cost and quantity were drawn independently per line. For
   low-cost, high-volume parts (e.g. resistor packs) a high-end cost
   roll ($500+) could combine with a high-end quantity roll (5,000
   units), producing a single PO line worth over $2.5M. This pushed
   total simulated 2-year company spend to an implausible $1.26B and
   skewed 76% of all spend into Manufacturing alone. **Fix:** added a
   `CATEGORY_MAX_LINE_VALUE` guardrail — if `unit_cost × quantity`
   exceeds a category-realistic ceiling, quantity gets capped down
   before pricing. Total completed spend after the fix: ~$503M over 2
   years (~$252M/yr) — reasonable for a ~1,000-employee company doing
   its own manufacturing/assembly, since procurement here covers
   production materials and components, not just G&A spend. Still a
   judgment call, not a fact — worth revisiting if it looks off once
   we're deeper into analysis.

**Why this matters:** both issues are generator defects, not business
signal. Treating them as bugs to fix rather than something to explain
away analytically later.

**Status:** Checkpoint 2 (data generated and validated) — see
`documentation/methodology.md` for the full inspection report.
Provisionally **PASSED**.

---

## 2026-09-18 — KPI grain clarification: delivery metrics defined at PO-line level

**Decision:** Clarify PROJECT_SPEC.md's KPI definitions to state
explicitly that delivery metrics operate at the PO-line grain, matching
the fact table — not left ambiguous between "purchase order" and "PO
line."

**What we found:** External review flagged that phrasing like
"Completed POs, delivered ≤ Expected_Delivery_Date" doesn't define what
happens when one PO_ID has multiple lines with different delivery
outcomes (e.g. PO-1801: Component A on time, Component B late,
Component C on time). Since the fact table grain is one row per PO
line, "PO delivered on time" wasn't actually a well-defined statement.

**Fix:** Updated PROJECT_SPEC.md to:
- Add an explicit "Fact table grain" section stating the grain and why
  it matters for delivery KPIs specifically.
- Reword **On-Time Delivery %** and **Average Days Late** to say "PO
  lines" instead of "POs," so it's clear these are line-grain.
- Reword **PO Count** to show `COUNT(DISTINCT PO_ID)` explicitly and
  note it's a separate, PO-level metric.
- Updated the Inclusion Rules section to match.

**Why this matters:** the fact table design was already correct — this
was a wording gap, not a design flaw. But if the SQL/DAX ends up
line-grain while the spec implies PO-grain, that's exactly the kind of
inconsistency an interviewer would poke at. Fixing it now, before any
analytical SQL gets written, means every downstream query starts from
an unambiguous definition instead of needing a retroactive fix later.

**Status:** Applied to PROJECT_SPEC.md directly. No schema or generator
changes needed — definitions-only fix.

---

## 2026-09-19 — Removed CHANGELOG.md

**Decision:** Delete `CHANGELOG.md`.

**Why:** It was duplicating content already in DECISIONS.md — same bug
narratives, same specifics — without serving a distinct purpose. Commit
history already covers "what changed, when"; DECISIONS.md covers "why."
No reason to maintain a third overlapping history.

**Fix:** Removed the file. Going forward: "what happened" lives in
commit history, "why" lives here.

---

## 2026-09-20 — New finding: PO_Line_ID collisions (9 cases)

**Decision:** Extended `01_data_quality.sql`'s duplicate check to also
catch PO_Line_ID values that repeat with genuinely different data
underneath — a different problem than the 128 full-row duplicates
already found.

**What we found:** 9 PO_Line_ID values each show up on exactly 2 rows
where the rest of the data doesn't fully match — meaning the ID got
reused, not the row copied. Looked at all 9 by hand:
- **8 cases** — every column matches except one, where one row has a
  NULL or malformed value and the other has a valid one for that same
  field (e.g. L005513: identical row, one copy just missing
  Expected_Delivery_Date). Reads as the same real transaction with one
  incomplete copy, not two unrelated PO lines.
- **1 case (L014440)** — both rows have valid-looking but different
  Actual_Delivery_Date values (2025-02-08 vs 2025-02-13), everything
  else identical. Initially logged as unresolvable — see correction
  below.

**Fix (applied in `02_data_cleaning.sql`):** For each pair, keep the
row with no NULL/malformed/impossible values and drop the other. Not
inventing data — just picking the more complete of two rows describing
the same event.

**Why this matters:** this is a genuinely new pattern — an ID collision
overlapping with a missing/conflicting value — not something the first
audit pass caught. Documenting it before fixing it keeps the audit
(01_data_quality.sql) and the fix (02_data_cleaning.sql) honest with
each other.

**Status:** Detection query added to `01_data_quality.sql`. Fix applied
in `02_data_cleaning.sql`.

---

## 2026-09-20 — Correction: L014440 is resolvable, not a genuine conflict

**Decision:** Revise the entry above — L014440 was incorrectly
classified as an unresolvable value conflict.

**What we missed the first time:** Closer inspection shows L014440's
two Actual_Delivery_Date values aren't actually an unresolvable tie. One
(2025-02-08) falls before the row's own Order_Date (2025-02-10) —
physically impossible, using the same delivery-before-order rule already
established in `01_data_quality.sql` section 5. The other (2025-02-13)
is valid. This resolves the same way as the other 8 collision cases, not
as a special case.

**Fix:** Added a 5th check to the collision-resolution logic in
`02_data_cleaning.sql` — "Actual_Delivery_Date before Order_Date" —
reusing the delivery-before-order rule. All 9 collision pairs now
resolve uniformly through one scoring rule; no row-merging or
null-override logic needed for L014440 after all.

**Why this matters:** good reminder to actually check the data before
calling something unresolvable — this one just needed the right rule
applied, not a judgment call.

**Status:** Logic corrected before being built into `02_data_cleaning.sql`,
so the wrong version never made it into the actual pipeline.

---

## 2026-09-20 — Checkpoint 3: 02_data_cleaning.sql built and verified

**Decision:** Build `dbo.fact_purchase_orders` from
`stg_fact_purchase_orders` — dedup, PO_Line_ID collision resolution,
type conversion (DATE/DECIMAL on raw nvarchar columns), and Currency/
PO_Status standardization, all in one script.

**Approach:**
- Dedup via `ROW_NUMBER()` partitioned on all 12 columns, keeping `rn = 1`.
- Collision resolution via a per-row "badness score" (count of NULL/
  malformed/impossible values across Unit_Price, Quantity, Order_Date,
  Expected_Delivery_Date, Actual_Delivery_Date-before-Order_Date),
  keeping the row with `badness_score = 0` for each of the 9 known
  collision IDs, leaving all other rows untouched regardless of score.
- Currency/PO_Status standardized via CASE WHEN ('US Dollar' → 'USD',
  'Canceled' → 'Cancelled').
- Raw text values cast to real types (DATE, DECIMAL(10,2)) on insert.
- Invalid values (negative price, zero quantity, malformed dates on
  otherwise-unique rows) are NOT deleted — they convert to NULL and the
  row stays, per the inclusion-rules philosophy in PROJECT_SPEC.md. Only
  rows with a verified full-row duplicate or a resolvable ID collision
  get removed, since those are the only cases where a row is confirmed
  to have an intact "backup" elsewhere in the data.

**Verified:**
- Final row count: 19,579 (19,716 − 128 duplicates − 9 collision-pair
  excess rows).
- Currency: single value, USD, across all rows.
- PO_Status: exactly 3 values (Completed, Open, Cancelled) — no
  "Canceled" remaining.
- No PO_Line_ID appears more than once.
- 14 rows have Order_Date = NULL — matches the 16 malformed dates found
  in 01_data_quality.sql minus the 2 that were also collision cases
  (now resolved). These 14 are kept, not deleted, per the invalid-values
  philosophy above.

**Note:** mid-build, the INSERT was accidentally run 5 times (97,895
rows instead of 19,579) before being caught by cross-checking the row
count against the Currency/PO_Status group-by totals. Fixed via
TRUNCATE + single re-run. Left here as a reminder that INSERT isn't
idempotent — re-running it doesn't overwrite, it adds on top.

**Status:** `dbo.fact_purchase_orders` complete and verified. Remaining
for Checkpoint 3: build the four dimension tables (dim_vendor,
dim_product, dim_department, dim_date) the same way.