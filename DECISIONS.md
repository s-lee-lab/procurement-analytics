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
