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

**Why:** It was duplicating content already in