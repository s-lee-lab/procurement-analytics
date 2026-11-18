# DECISIONS LOG — Procurement Spend & Vendor Performance Analytics

This log records meaningful analytical, technical, and methodological decisions made throughout the project.

The purpose is to preserve not only what changed, but why a particular approach was chosen, what was learned, and what should be considered when interpreting the results.

---

## 2026-09-07 — Checkpoint 1: Requirements and Architecture Locked

**Decision**

Finalize the initial business requirements and technical architecture before generating data or writing analytical SQL.

**Scope established**

- Fictional company: Northstar Electronics.
- Primary stakeholder: Procurement Manager.
- Supporting stakeholders: Finance Manager and Operations Manager.
- Five-table star schema.
- PO-line-level fact table grain.
- Explicit spend, delivery, and vendor KPI definitions.
- Synthetic data generation with controlled data-quality issues.
- Excel / Power Query → SQL → Power BI workflow.

**Why it matters**

Establishing the business questions and data grain upfront prevents the project from becoming a collection of disconnected technical exercises.

The analytical work should answer recognizable procurement questions, and every metric should have a clear definition before implementation.

**Status:** Complete. See `PROJECT_SPEC.md` and `DATA_DICTIONARY.md`.

---

## 2026-09-07 — Deliverable 1: Synthetic Data Generator Built and Two Bugs Fixed

**Decision**

Build `python/generate_data.py` to produce five raw CSV files, then inspect the generated data before using it for analysis.

The guiding principle is to fix generator defects at the source rather than compensate for unrealistic data downstream.

**Finding 1: Delivery-date logic bug**

For products with very short lead times (1–2 days), the generated early/on-time delivery offset (`random.randint(-3, 0)`) could produce an Actual_Delivery_Date before the Order_Date.

This was physically impossible, not a legitimate business anomaly.

- Initially affected 599 of approximately 19,300 rows.
- Corrected the generator so the early-delivery offset cannot exceed the product's lead time.
- After the correction, only the intentionally injected bad-date records remained.

**Finding 2: Unrealistic Manufacturing line values**

Unit cost and quantity were initially generated independently.

For low-cost, high-volume components, a high unit-cost draw combined with a large quantity could produce an individual PO line exceeding $2.5M.

This caused:
- Approximately $1.26B in simulated two-year company spend.
- Manufacturing accounting for approximately 76% of total spend.

**Implementation**

Added a `CATEGORY_MAX_LINE_VALUE` guardrail. When a generated line exceeded its category-specific ceiling, quantity was capped before pricing.

**Verified result**

Completed spend after the correction was approximately $503M over two years, or approximately $252M annually.

This was considered a reasonable synthetic scale for a manufacturer with approximately 1,000 employees purchasing both production materials and corporate supplies.

**Why it matters**

Both issues were generator defects, not meaningful procurement findings. Fixing them at the source prevents unrealistic conditions from distorting subsequent analysis.

**Status:** Complete. Generator inspected and accepted. The approximately $250M annual spend assumption remains a design choice, not a real-world benchmark.

See `documentation/methodology.md`.

---

## 2026-09-18 — KPI Grain Clarification: Delivery Metrics Defined at PO-Line Level

**Decision**

Explicitly define delivery KPIs at PO-line grain to match the fact table.

**Finding**

A purchase order can contain multiple product lines with different delivery outcomes.

For example, one PO could contain two lines delivered on time and another delivered late. Calling the entire PO either on time or late would be ambiguous without an additional aggregation rule.

**Implementation**

Updated `PROJECT_SPEC.md` to:

- Define `fact_purchase_orders` as one row per PO line.
- Calculate On-Time Delivery % using eligible Completed PO lines.
- Calculate Average Days Late using late Completed PO lines.
- Define PO Count separately using `COUNT(DISTINCT PO_ID)`.

**Why it matters**

The fact table was already designed correctly. The issue was that the original KPI wording did not clearly communicate the calculation grain.

Resolving this before analytical SQL was written prevented inconsistencies between business requirements and implementation.

**Status:** Complete. Definitions updated; no schema or generator changes required.

---

## 2026-09-19 — CHANGELOG.md Removed

**Decision**

Remove `CHANGELOG.md`.

**Why**

The file duplicated information already maintained in `DECISIONS.md`.

Maintaining separate documents for the same technical history created unnecessary overhead.

Going forward:
- Git commit history records what changed.
- `DECISIONS.md` explains why decisions were made and what was learned.

**Status:** Complete.

---

## 2026-10-04 — Data Quality Discovery: PO_Line_ID Collisions

**Decision**

Extend `01_data_quality.sql` to detect reused PO_Line_ID values with conflicting underlying records, rather than checking only for exact duplicate rows.

**Finding**

Nine PO_Line_ID values appeared twice with differences in the underlying data.

Manual inspection identified:

- **Eight cases:** One record contained a NULL or malformed value where the other contained a valid value.
- **One case (L014440):** Both records contained apparently valid but different Actual_Delivery_Date values.

The nine cases represented reused identifiers, not ordinary full-row duplicates.

**Implementation**

Added collision detection to `01_data_quality.sql`.

The intended cleaning approach was to retain the more complete record for each pair.

**Why it matters**

A duplicate identifier does not necessarily mean two identical records.

Distinguishing exact duplicates from conflicting identifier reuse makes the cleaning process more transparent and defensible.

**Status:** Detection implemented. Resolution logic corrected in the following entry.

---

## 2026-10-04 — Correction: L014440 Was Resolvable

**Decision**

Correct the original classification of L014440 as an unresolvable conflict.

**Finding**

Closer inspection showed:

- One Actual_Delivery_Date was February 8, 2025.
- The corresponding Order_Date was February 10, 2025.
- The second Actual_Delivery_Date was February 13, 2025.

The first delivery date was physically impossible because it preceded the order date.

The second record was valid.

**Implementation**

Added a fifth condition to the collision-resolution scoring logic in `02_data_cleaning.sql`:

`Actual_Delivery_Date < Order_Date`

This allowed all nine collision pairs to be resolved using the same record-completeness approach.

**Why it matters**

The initial investigation reached the wrong conclusion because it had not applied the existing date-validity rule to both records.

This is a useful reminder that data-quality conclusions should follow inspection and validation, not assumptions based on the first appearance of a conflict.

**Status:** Complete. The incorrect resolution logic was corrected before being incorporated into the final cleaning pipeline.

---

## 2026-10-04 — Checkpoint 3: SQL Cleaning Pipeline Built and Verified

**Decision**

Build the cleaned fact table, `dbo.fact_purchase_orders`, from `stg_fact_purchase_orders`.

The cleaning script handles deduplication, identifier collisions, data-type conversion, and categorical standardization.

**Implementation**

`02_data_cleaning.sql` uses:

- `ROW_NUMBER()` partitioned across all 12 columns to remove exact duplicate rows.
- A per-row badness score to resolve the nine PO_Line_ID collisions.
- `CASE WHEN` logic to standardize Currency and PO_Status.
- Conversion of raw text values into DATE and DECIMAL types.
- NULL conversion for malformed values that cannot be cast.

The collision-resolution score evaluates:
1. Missing or invalid Unit_Price.
2. Missing or invalid Quantity.
3. Missing or malformed Order_Date.
4. Missing or malformed Expected_Delivery_Date.
5. Actual_Delivery_Date preceding Order_Date.

The more complete record is retained for the nine known collisions. Other records with invalid values remain in the table.

**Important cleaning distinction**

- Malformed text values that fail conversion become NULL.
- Negative and zero numeric values convert normally and remain in the cleaned table.
- Invalid values on otherwise unique records are not deleted.
- Only verified exact duplicates and resolvable identifier collisions are removed.

**Verified results**

| Validation | Result |
|---|---:|
| Raw fact rows | 19,716 |
| Exact duplicate rows removed | 128 |
| Excess collision rows removed | 9 |
| Final cleaned fact rows | 19,579 |
| Remaining duplicate PO_Line_ID values | 0 |
| Currency values | USD only |
| PO_Status values | Completed, Open, Cancelled |
| NULL Order_Date values | 14 |

The 14 NULL Order_Date values reconcile to the 16 malformed dates originally detected in `01_data_quality.sql`, minus the two records resolved through identifier-collision cleaning.

**Execution issue discovered**

During development, the INSERT operation was accidentally executed five times, producing 97,895 rows instead of 19,579.

Cross-checking row counts against Currency and PO_Status group totals exposed the problem.

The table was rebuilt using TRUNCATE and a single INSERT execution.

**Permanent improvement**

Added `DROP TABLE IF EXISTS` before table creation so the cleaning pipeline can be rerun safely from scratch.

**Why it matters**

The cleaning process preserves questionable but potentially meaningful records while removing only confirmed duplicates and redundant collision records.

The rebuild approach also makes the pipeline reproducible instead of dependent on manual database cleanup.

**Status:** Complete. Fact table built and verified.

---

## 2026-10-19 — Dimension Tables Built and Validated

**Decision**

Build the four dimension tables from their respective staging tables using explicit data types, primary keys, and repeatable DROP/CREATE/INSERT logic.

**Dimensions**

- `dim_department`
- `dim_vendor`
- `dim_product`
- `dim_date`

**Validation performed**

Before loading, each dimension was checked for:

- Duplicate primary keys.
- Missing or blank fields.
- Failed type conversions.
- Unnecessary whitespace.
- Categorical spelling inconsistencies.
- Date-table completeness.
- Orphan fact-table keys.

**Findings**

All four dimensions passed validation.

No duplicate IDs, missing required fields, failed conversions, padded text, or categorical spelling inconsistencies were found.

There were also no orphan fact-table keys.

**Verified row counts**

| Table | Rows |
|---|---:|
| dim_department | 9 |
| dim_vendor | 41 |
| dim_product | 107 |
| dim_date | 731 |

The date dimension covers January 1, 2024 through December 31, 2025.

The entire `02_data_cleaning.sql` script was rerun successfully, reproducing all five expected row counts.

**Additional observations**

- All 41 vendors are marked Active. Vendor_Status cannot distinguish vendors in this dataset.
- Vendor_Category and Product_Category share the same seven category labels.
- The Week column represents seven-day blocks beginning January 1, rather than ISO week numbering.

**Why it matters**

The dimension tables did not require the deduplication and collision-resolution logic used for the fact table.

Primary keys provide an additional safeguard against duplicate dimension identifiers during future rebuilds.

**Status:** Complete. Checkpoint 3 (SQL cleaning and dimensional modeling) passed.

**Next:** `03_spend_analysis.sql`.

---

## 2026-10-26 — Spend Analysis: End-of-Data Effect Identified

**Decision**

Keep Completed-only spend as the primary financial KPI definition, but explicitly flag the distortion this creates in the most recent reporting periods.

**Finding**

December 2025 Completed spend drops to approximately $11.9M, compared with the usual monthly range of approximately $17M–$27M.

However, total purchasing activity does not show a comparable decline.

| Metric | September 2025 | October 2025 | December 2025 |
|---|---:|---:|---:|
| Total PO lines | 910 | 929 | 863 |
| Open lines | 30 | — | 387 |

December's Completed plus Open spend is approximately $21.0M, consistent with a normal purchasing month.

The decline is therefore primarily an end-of-data effect: many late-period orders remain Open and are excluded from Completed-only spend.

**Financial impact**

| Metric | 2024 | 2025 |
|---|---:|---:|
| Completed-only year-over-year growth | | +1.5% |
| Completed + Open ordered spend | $260.17M | $272.19M |

Ordered-spend growth is approximately 4.62%.

Completed-only growth understates the change in purchasing activity.

**Handling**

- Retain Completed-only spend for financial KPIs.
- Use Completed plus Open spend when examining purchasing activity.
- Display Open spend separately as pipeline.
- Flag or footnote the final one to two months of Completed-only trend visuals.

**Additional findings**

- Completed spend: $499.65M.
- Average PO value: $62,347.
- Distinct Completed POs: 8,014.
- Vendors with Completed purchasing activity: 41.
- Invalid Quantity/Unit_Price records excluded: up to 239 of 17,739 Completed lines.
- Nine Completed lines with NULL Order_Date represent $163,568 of otherwise eligible spend.

The nine lines remain in overall spend totals but cannot be assigned to a valid time period.

Yearly spend plus these nine lines reconciles to total spend.

Approximately $12.3M of 2024 orders remain Open at the end of 2025. This was retained as an operational question rather than treated as a confirmed finding.

**Category observation**

Software accounts for approximately 27.9% of spend, or roughly $70M annually.

This is a generated category distribution, not an industry benchmark.

**Documentation correction**

An earlier statement implied that negative and zero numeric values convert to NULL during cleaning.

This was incorrect. Only malformed values that fail conversion become NULL. Negative and zero values remain in the cleaned table and are excluded by analytical filters.

The decision log and cleaning-script header were corrected.

**Why it matters**

The distinction between purchasing activity and completed financial activity is important when interpreting trends.

A reporting decline should not automatically be interpreted as a real reduction in procurement demand.

**Status:** Complete. `03_spend_analysis.sql` verified.

**Next:** `04_vendor_performance.sql`.

---

## 2026-11-02 — Vendor Performance: Delivery KPIs and Calendar-Coverage Gap

**Decision**

Calculate delivery KPIs at PO-line grain using Completed lines with valid Expected and Actual delivery dates.

Do not use the existing `dim_date` relationship to filter delivery dates because the calendar does not cover the complete delivery period.

**Findings: Supplier concentration**

- Top 10 of 41 vendors account for 56.8% of spend.
- 19 vendors account for 80% of spend.
- HHI is 439, compared with approximately 244 under an equal distribution.
- No vendor or category is dominated by a single supplier.
- The largest category leader accounts for 37.9% of its category.

Eight single-source products account for 4.9% of spend. Three consulting and software products represent approximately 87% of that single-source spend.

**Findings: Delivery performance**

- Overall on-time delivery: 75.8%.
- Average delay among late lines: 12.6 days.
- Approximately half of late lines are at least eight days late.
- Vendor on-time performance ranges from 52.8% to 97.2%.
- Category performance ranges from approximately 66% to 82%.
- Department performance ranges from approximately 72% to 79%.

Vendor-level differences appear larger than category, department, or regional differences.

This suggests vendor-level investigation may be useful, but the apparent relationship was not statistically tested.

**Vendor spend-share observation**

The initial analysis reported that the 15 vendors below 70% on-time delivery held 33.2% of total spend.

This figure requires reconciliation with a later README figure of 34.9%. Neither figure should be treated as final until the underlying SQL calculation and denominator are verified.

**Delivery exclusions**

Of 17,739 Completed lines:

- 79 have no Expected_Delivery_Date.
- 12 have Actual_Delivery_Date before Order_Date.
- 17,648 remain eligible for delivery analysis.

These records are excluded from the applicable KPI calculations, not deleted from the fact table.

**Calendar-coverage issue**

Order activity ends December 31, 2025, but Completed delivery records extend through April 19, 2026.

The existing `dim_date` table also ends December 31, 2025.

An earlier inner join between Actual_Delivery_Date and `dim_date` silently excluded 158 valid delivery records, reducing the analytical population from 17,648 to 17,490.

**Implementation**

Changed the delivery analysis to derive delivery periods directly from Actual_Delivery_Date.

This preserves all 17,648 eligible lines.

The existing `dim_date` relationship remains based on Order_Date.

**Caveats**

- Only delivered Completed lines are measured.
- Overdue orders still marked Open do not count against vendor on-time performance.
- The 2026 delivery months have relatively small samples and potentially reflect late-2025 orders that slipped.
- Regional comparisons require caution because the Midwest contains only three vendors.

**Why it matters**

A technically valid relationship can still produce an incomplete analytical population when its date coverage is insufficient.

The issue was discovered by reconciling row counts rather than relying on the query to execute successfully.

**Status:** Core delivery and concentration analysis complete. Section 12's Open-order aging analysis was subsequently documented on November 10.

---

## 2026-11-02 — Project Scope Reviewed Against Job Postings

**Decision**

Compare the existing project plan against approximately 15 individual job postings and several aggregated listings for procurement, supply chain, and BI analyst positions.

Extend the existing project where recurring job requirements reveal meaningful gaps. Do not restart the project or introduce unrelated technical work.

This was a qualitative review, not a statistical labor-market study.

**Skills already covered**

- SQL.
- Spend analysis.
- Supplier performance.
- Vendor concentration.
- Data quality and validation.
- KPI definitions.
- Version control.
- BI reporting plans.

**Identified gaps and corresponding deliverables**

| Employer requirement | Project addition |
|---|---|
| Savings opportunity sizing | `06_opportunity_analysis.sql` |
| Savings business cases and tracking | Excel savings opportunity model |
| Purchase Price Variance | `05_pricing_analysis.sql` |
| Supplier scorecards | `06_opportunity_analysis.sql` |
| Past-due purchasing reports | Open-line exception analysis |
| Advanced Excel / Power Query | `excel/savings_opportunity_model.xlsx` |
| DAX and semantic modeling | Power BI measures and model |
| Row-level security and Power BI Service | Power BI implementation |
| Requirements gathering and UAT | `documentation/uat_plan.md` |
| Forecasting | `07_spend_forecast.sql` |
| Stakeholder communication | One-page executive brief |

**Deliberately excluded**

- Inventory and MRP.
- Contract compliance.
- Maverick-spend analysis.
- OTIF.
- Machine-learning forecasting.
- Cloud data platforms.

The current synthetic dataset does not support these areas reliably without additional data generation and revalidation.

**Caveats**

The forecast has only 24 monthly observations. Savings scenarios rely on synthetic pricing data and assumed recovery rates.

These deliverables demonstrate analytical methods, not real-world financial results.

**Why it matters**

The project should demonstrate capabilities employers repeatedly request without becoming an unrealistic imitation of an enterprise procurement system.

**Status:** Scope additions incorporated into `TASKS.md`.

---

## 2026-11-10 — Open-Order Aging: Generator Status Is Not a Backlog Finding

**Decision**

Retain the Open-order aging analysis in `04_vendor_performance.sql` as an illustrative exception report, not a confirmed supplier-backlog finding.

Calculate aging using two reference dates:

- December 31, 2025 — primary view.
- April 19, 2026 — sensitivity view.

**Why two dates are necessary**

The generator assigns PO_Status primarily according to order recency as of December 31, 2025.

However, Completed lines contain delivery dates extending through April 19, 2026.

These dates do not describe a consistent operational snapshot.

This corrects the earlier November 2 wording that suggested the dataset had a later overall snapshot date.

**Results**

The analysis identifies 1,216 Open lines with an Expected_Delivery_Date, representing $32,855,041.

| Aging bucket | As of Dec. 31, 2025 | As of Apr. 19, 2026 |
|---|---:|---:|
| Not yet due | 151 lines / $4.34M | 0 |
| 1–30 days | 260 lines / $6.29M | 0 |
| 31–90 days | 103 lines / $2.42M | 15 lines / $0.94M |
| 91–180 days | 100 lines / $2.91M | 472 lines / $11.50M |
| 180+ days | 602 lines / $16.89M | 729 lines / $20.42M |
| Total | 1,216 lines / $32.86M | 1,216 lines / $32.86M |

**Generator behavior discovered**

In `generate_data.py`, PO_Status is assigned primarily by order recency:

- 60% Open in the last 20 days of the window.
- 20% Open in the preceding 25 days.
- 4% Open for older orders.

Vendor identity and Expected_Delivery_Date do not determine the status assignment.

Consequently, many older Open orders remain Open because the generator does not simulate a realistic order-closing process.

**Additional validation**

The top 10 vendors account for 56.7% of overdue Open spend as of December 31, 2025, almost identical to their 56.8% share of overall spend.

This supports the interpretation that the ranking largely reflects vendor purchasing volume rather than demonstrated supplier behavior.

Vendor on-time performance is unaffected because it uses Completed lines only.

**Handling**

- Retain aging buckets and exception reporting.
- Label the report illustrative.
- Show the reference date prominently.
- Include the generator limitation in the final project documentation.

**Why it matters**

A large overdue Open-order balance may look like an important operational finding, but the synthetic status-generation logic does not support that conclusion.

Understanding how the data was generated is necessary before making a business recommendation.

**Status:** Analysis complete. Generator limitation documented.

---

## 2026-11-16 — Opportunity Analysis: Price-Leakage Sizing and Supplier Scorecard

**Decision**

Estimate potential price leakage using vendor-product pairs with sufficient purchasing history and prices above the product-level median.

The analysis uses:

- Minimum 10 PO lines per vendor-product pair.
- Price index greater than 1.05.
- Positive purchase price variance.
- Low/base/high recovery scenarios of 25%, 50%, and 75%.

The results represent two years of synthetic purchasing activity.

**Pricing methodology**

The primary benchmark is the observed median unit price for each product across valid Completed purchasing activity from both years and all vendors.

`Price Index = Observed Vendor Price / Product Median Price`

The opportunity analysis identifies pairs where the vendor price index exceeds 1.05.

The median is a relative comparison benchmark, not a verified fair market price.

**Results**

| Metric | Result |
|---|---:|
| Flagged vendor-product pairs | 96 |
| Vendors represented | 19 |
| Products represented | 81 |
| Theoretical price-gap ceiling | $17.32M |
| Gap as a share of total spend | 3.47% |
| Low recovery scenario | $4.33M |
| Base recovery scenario | $8.66M |
| High recovery scenario | $12.99M |

Manufacturing and Software account for approximately 74% of the theoretical price-gap ceiling.

Excluding vendors with on-time performance of 85% or higher, the base scenario is approximately $5.32M.

**Combined pricing and delivery observation**

Five vendors are both above the product benchmark and below 70% on-time delivery:

- Lakeside.
- Lighthouse.
- Pinnacle.
- Anchor.
- Ironclad.

Together, they represent approximately $89.8M in spend (18%) and $8.2M of the theoretical price-gap ceiling.

These suppliers warrant further investigation. The analysis does not establish that their prices are unreasonable or that their delivery performance is caused by supplier behavior.

**Supplier scorecard**

The initial composite scorecard uses the following judgment-based weights:

| Metric | Weight |
|---|---:|
| On-time delivery | 40% |
| Average days late | 20% |
| Price performance | 30% |
| Supplier concentration | 10% |

Metrics are min-max scaled across vendors.

The weighting prioritizes delivery reliability while still recognizing pricing and concentration risk.

The scorecard should clearly explain the direction of each metric, the normalization method, and the treatment of missing or insufficient observations before being presented as a final vendor ranking.

**Supplier tail**

- 22 vendors account for 19.3% of spend.
- Average spend per vendor is approximately $4.4M.

The remaining spend is not sufficiently fragmented to support an automatic supplier-consolidation recommendation.

**Caveats**

- Recovery rates are assumptions, not measured savings.
- The $17.32M gap is a theoretical ceiling, not achievable savings.
- The median for a two-vendor product is simply the midpoint between two observed prices.
- Delivery risk is not converted into dollars because the dataset lacks delay-cost information.
- Open-order aging remains illustrative, as documented on November 10.

**Why it matters**

The analysis moves beyond descriptive reporting by translating price differences into transparent opportunity scenarios.

It also combines pricing and delivery metrics to identify vendors that may warrant more detailed procurement review.

**Status:** Core opportunity analysis and scorecard calculations documented. Scorecard direction and normalization should be explicitly validated in the final reporting documentation.

---

## 2026-11-16 — Spend Forecast: Method Selected Using Two Backtest Origins

**Decision**

Forecast monthly ordered spend (Completed + Open) for January through June 2026 using a six-month moving average (`MA6`).

The method was selected based on pooled WAPE across two historical backtest origins.

**Why ordered spend**

Completed-only spend is affected by the end-of-data artifact described on October 26.

Using Completed plus Open purchasing activity better represents the monthly value of orders placed and provides a more consistent basis for the exploratory forecast.

**Backtest methodology**

Two historical forecast origins were evaluated.

| Backtest | Training period | Holdout period |
|---|---|---|
| Origin 1 | Through June 2025 | July–December 2025 |
| Origin 2 | Through December 2024 | January–June 2025 |

**Findings**

The first backtest favored Seasonal Naive:

- Seasonal Naive WAPE: 7.1%.
- Flat-method comparison: 9.7%.

However, seasonality was not consistent across the full year.

The monthly profile correlation between 2024 and 2025 was:

- July–December: 0.67.
- January–June: 0.06.

The second backtest, covering January–June 2025, ranked Seasonal Naive worst at 13.1% WAPE and MA6 best at 5.7%.

**Pooled results**

Across the 12 holdout months:

| Method | Pooled WAPE |
|---|---:|
| MA6 | 7.69% |
| Mean of all historical months | 7.93% |

MA6 also had a pooled bias of +0.25%.

The difference between MA6 and the all-history mean is small, but MA6 had the lowest pooled WAPE among the evaluated methods.

**Forecast**

The January–June 2026 forecast is approximately:

- $22.40M per month.
- $134.4M across six months.
- Rough range: $20.66M–$24.14M per month.

The rough range uses pooled MAE, and 7 of the 12 historical holdout actuals fell inside it.

**Limitations**

- Only 24 monthly observations are available.
- The evaluation uses 12 holdout observations.
- Method selection occurred after reviewing the holdout results, introducing some selection bias.
- Four flat methods tie on MAE in the July–December backtest.
- The method assumes no underlying trend.
- Historical backtest performance does not guarantee future accuracy.

**Why it matters**

The forecast demonstrates a structured approach to selecting and evaluating a baseline forecasting method instead of choosing a technique based on appearance or complexity.

The results should be communicated as an exploratory estimate, not a reliable production forecast.

**Status:** Forecast analysis and two-origin backtesting complete.

---

## 2026-11-17 — Documentation Consistency Review

**Decision**

Reconcile the project specification, data dictionary, decision log, README, and task tracker before finalizing the portfolio documentation.

The purpose is to ensure that each document describes the same analytical implementation and that historical assumptions are not mistaken for current methodology.

**Items reviewed**

- Business requirements and project scope.
- Fact table grain and KPI definitions.
- Cleaning logic and verified table counts.
- Date coverage and delivery-date treatment.
- Vendor and product benchmark methodology.
- Spend and delivery eligibility rules.
- Savings opportunity sizing.
- Supplier scorecard methodology.
- Forecast selection and limitations.

**Outstanding verification items**

1. **Vendor underperformance spend share:** The November 2 analysis reports 33.2%, while the current README reports 34.9%. Reconcile the SQL query, vendor population, threshold, and spend denominator before selecting the final number.

2. **Supplier scorecard:** Confirm metric direction, normalization, and missing-observation handling. The documented weights are judgment-based and should not be presented as statistically optimized.

3. **Date modeling:** The SQL delivery analysis correctly avoids the incomplete 2024–2025 date dimension. The future Power BI model must support delivery reporting through April 19, 2026.

4. **Savings assumptions:** Keep the $17.32M price-gap ceiling separate from the low/base/high recovery scenarios. Do not describe any of these values as realized savings.

5. **Implementation status:** Planned Excel and Power BI deliverables must remain clearly distinguished from completed SQL work until the actual files and models are built and validated.

**Why it matters**

Documentation should make it possible for another analyst or interviewer to follow the project from business requirements through implementation and results without encountering conflicting definitions or unsupported claims.

**Status:** Documentation review in progress. Outstanding items should be closed through source-query verification rather than editorial judgment.

---

## Documentation Maintenance Rules

Going forward, use these standards when updating this log:

1. Record meaningful changes to analytical methodology, data cleaning, KPI definitions, or business assumptions.
2. Preserve corrections to earlier decisions rather than silently rewriting history.
3. Distinguish verified results from hypotheses, estimates, and scenario assumptions.
4. Include the SQL script or deliverable associated with a decision whenever applicable.
5. Keep historical entries chronological and avoid duplicating the README's full project narrative.
6. Update `PROJECT_SPEC.md` and `DATA_DICTIONARY.md` when a decision changes project requirements, data definitions, or calculation rules.
7. Update `TASKS.md` when a decision creates, completes, or changes an implementation task.

**Final standard:** Every important decision should be explainable, every reported number should be traceable to its source, and every limitation should be disclosed before the project is presented to stakeholders or employers.