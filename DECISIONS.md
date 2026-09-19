# DECISIONS LOG

Records meaningful decisions made during the project and why.

---

## 2026-09-07 — Checkpoint 1: Requirements & Architecture Locked

All business scope, stakeholders, business questions, data architecture (5-table
star schema), KPI definitions, data-generation philosophy, and the AI operating
workflow were locked. See PROJECT_SPEC.md and DATA_DICTIONARY.md.

---

## 2026-09-07 — Deliverable #1: Generator built, two bugs found and fixed during inspection

**Decision:** Build `python/generate_data.py` to produce the five raw CSVs, then
independently inspect the output before trusting it — per the "we don't patch bad
data downstream, we fix the generator" rule.

**What we found on first inspection:**

1. **Delivery-date logic bug (fixed).** For products with very short lead times
   (1–2 days), the on-time/early delivery offset (`random.randint(-3, 0)`) could
   push `Actual_Delivery_Date` before `Order_Date` — a physically impossible
   result, not a deliberate data-quality issue. Affected 599 of ~19,300 rows
   before the fix. **Fix:** the early-delivery offset is now bounded by the
   product's own lead time, so a delivery can never be logged before the order
   was placed. After the fix, only the intentionally-injected invalid-date rows
   (13, ~0.07%) show this pattern — matching the small "controlled data quality
   issue" target from PROJECT_SPEC section 15.

2. **Unrealistic line totals in Manufacturing "Components" (fixed).** Unit cost
   and quantity were drawn independently per line. For low-cost, high-volume
   parts (e.g. resistor packs) a high-end cost roll ($500+) could combine with a
   high-end quantity roll (5,000 units), producing a single PO line worth over
   $2.5M. This pushed total simulated 2-year company spend to an implausible
   $1.26B and skewed 76% of all spend into Manufacturing alone. **Fix:** added a
   `CATEGORY_MAX_LINE_VALUE` guardrail — if `unit_cost × quantity` exceeds a
   category-realistic ceiling, quantity is capped down for that line before
   pricing. Total completed spend after the fix: ~$503M / 2 years (~$252M/yr),
   which we judge plausible for a ~1,000-employee company with in-house
   manufacturing/assembly (procurement here includes production materials and
   components, not just G&A spend) — but this is a modeling judgment, not a
   fact, and we flag it as revisitable if it looks off once we're deeper into
   analysis.

**Why this matters for the project's credibility:** both issues are examples of
*data-generation defects*, not business signal. We are treating them as bugs to
fix in the generator rather than something to "explain away" analytically —
consistent with the project's stated philosophy of not blindly trusting the
generator (section 16 of PROJECT_SPEC).

**Status:** Checkpoint 2 (data generated and validated) — see
`documentation/methodology.md` for the full inspection report. Provisionally
**PASSED**, pending your review of the numbers below.

---

## 2026-09-18 — KPI grain clarification: delivery metrics defined at PO-line level

**Decision:** Clarify PROJECT_SPEC.md's KPI definitions to explicitly state
that delivery metrics operate at the PO-line grain, matching the fact table,
rather than leaving "PO" ambiguous between "purchase order" and "PO line."

**What we found:** External review flagged that phrases like "Completed POs,
delivered ≤ Expected_Delivery_Date" don't define what happens when a single
PO_ID has multiple lines with different delivery outcomes (e.g. PO-1801:
Component A on time, Component B late, Component C on time). Since the fact
table grain is one row per PO line, and a PO can span multiple lines, "PO
delivered on time" was not a well-defined statement as written.

**Fix:** Updated PROJECT_SPEC.md to:
- Add an explicit "Fact table grain" section stating the grain and why it
  matters for delivery KPIs specifically.
- Reword **On-Time Delivery %** and **Average Days Late** to say "PO lines"
  instead of "POs," making clear these are calculated at line grain.
- Reword **PO Count** to explicitly show `COUNT(DISTINCT PO_ID)` and note it
  is a separate, PO-level metric — not to be confused with the line-level
  delivery KPIs.
- Updated the Inclusion Rules section to match ("Completed PO lines" instead
  of "Completed POs" for delivery).

**Why this matters for the project's credibility:** the underlying data and
fact-table design were already correct — this was a documentation-clarity
gap, not a design flaw. But if the SQL/DAX for On-Time Delivery % is written
at line grain while the spec's wording implies PO grain, that's exactly the
kind of inconsistency an interviewer would probe on. Fixing the wording now,
before `02_data_cleaning.sql` and the analytical SQL scripts are written,
means every downstream query is built against an unambiguous definition from
the start rather than needing a retroactive fix.

**Status:** Applied to PROJECT_SPEC.md directly (no schema or generator
changes required — this was a definitions-only fix).

---

## 2026-09-19 — Removed CHANGELOG.md

**Decision:** Delete `CHANGELOG.md` from the repo.

**Why:** On review, CHANGELOG.md was duplicating content already covered
by DECISIONS.md (same bug narratives, same specifics) rather than serving
a distinct purpose. Commit history (`git log`) already provides the
mechanical "what changed, when" record; DECISIONS.md carries the
reasoning and context. Maintaining a third overlapping history added no
value.

**Fix:** Removed CHANGELOG.md. Going forward, chronological "what
happened" lives in commit history; "why" lives here in DECISIONS.md.