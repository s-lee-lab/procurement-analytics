# TASKS — Active Queue

## COMPLETED

### Project Foundation & Data Generation
- Business problem, scope, stakeholders, and business questions
- Data architecture: five-table star schema
- KPI definitions and calculation grain
- Data-generation rules and data-quality strategy
- Project workflow ("AI Operating System")
- Build `python/generate_data.py`
- Generate raw dataset
- Inspect raw data: row counts, duplicates, nulls, invalid values, date ranges, distributions, relationship integrity, and business realism
- Validate data-quality injection rates against targets
- Validate business realism: department volume, department-to-category affinity, vendor concentration, delivery variance, and price variance
- Find and fix two generator bugs:
  - Impossible delivery dates
  - Unrealistic Manufacturing line totals
- Sign off on the inspection report, including the approximately $250M annual spend assumption
- Lock Checkpoint 2: Data Generation

### SQL Setup & Data Quality
- Clarify KPI grain: delivery KPIs at PO-line level; PO Count uses `COUNT(DISTINCT PO_ID)`
- Load CSVs into SQL Server as `stg_` staging tables, with all columns initially stored as `nvarchar`
- `sql/01_data_quality.sql`: read-only audit of staging tables, covering duplicates, missing and invalid values, formatting, invalid dates, and `PO_Line_ID` collisions
- `sql/02_data_cleaning.sql`: build all five cleaned `dbo.` tables from staging; script is re-runnable
- Resolve nine `PO_Line_ID` collision cases
- Verify dimension tables and confirm zero orphan keys against the fact table
- Verify cleaned row counts: 19,579 fact rows, 9 departments, 41 vendors, 107 products, and 731 dates
- Remove `CHANGELOG.md` because `DECISIONS.md` and Git commit history already capture project changes

### Analysis
- `sql/03_spend_analysis.sql`
  - Completed spend: $499.65M
  - Distinct POs: 8,014
  - Active vendors: 41
  - Spend by year, month, department, category, and subcategory
  - Reconciliation of totals to the cent
  - Identification of the December 2025 end-of-data effect

- `sql/04_vendor_performance.sql`
  - Vendor spend share and concentration
  - Top 10 vendors: 56.8% of spend
  - 19 vendors: approximately 80% of spend
  - HHI: 439
  - Eight single-source products
  - Overall On-Time Delivery: 75.8%
  - Average Days Late at PO-line grain
  - Open-order aging at December 31, 2025, with April 19, 2026 as a sensitivity date
  - Identification and correction of the delivery-date calendar coverage gap

- `sql/05_pricing_analysis.sql`
  - Purchase Price Variance against a product-level median benchmark
  - `Standard_Cost` retained as a secondary cross-check
  - Vendor price index range: 0.75–1.18
  - Volume-discount analysis
  - Year-adjusted price comparison

- `sql/06_opportunity_analysis.sql`
  - 96 flagged vendor-product pairs
  - $17.3M theoretical price-gap ceiling, or 3.47% of spend
  - Low / Base / High recovery scenarios: $4.3M / $8.7M / $13.0M
  - Three-or-more-vendor product sensitivity: $14.6M ceiling
  - Vendor scorecard analysis
  - Price-versus-on-time quadrants
  - Tail-spend analysis
  - Open-order report
  - Export grids for Excel

- `sql/07_spend_forecast.sql`
  - Monthly ordered-spend forecast
  - Two-origin backtest
  - Six-month moving average (`MA6`) selected using pooled backtest error
  - January–June 2026 forecast: approximately $22.4M per month

### Supporting Work
- Review job postings and identify relevant skill gaps
- Create `excel/excel_model_guide.md`
- Save SQL analysis exports under `excel/data/`
- Rewrite README with findings first, first-person explanations, and figures checked against query results
- Update GitHub profile bio, profile README, and portfolio landing page

---

## CURRENT

### 1. Documentation Reconciliation

The analysis is ahead of some of the project documentation. Bring the documents into agreement before building the presentation layer.

- [ ] **`DECISIONS.md`**
  - Record the November 10 Open-order aging findings and their limitations
  - Document the product-level median benchmark decision
  - Document opportunity sizing, recovery assumptions, and the two-vendor sensitivity
  - Document the vendor scorecard methodology and unresolved validation details
  - Record the two-origin forecast backtest and why MA6 was selected
  - Reconcile the under-70%-on-time vendor spend share to the verified SQL result

- [ ] **`04_vendor_performance.sql` and README**
  - Verify the 15 vendors below 70% on-time account for 34.92% of spend
  - Use the same verified figure in the SQL comments, README, and decision log

- [ ] **`PROJECT_SPEC.md`**
  - Specify the primary price benchmark: product-level median across both years and all vendors
  - Explain why `Standard_Cost` is a cross-check rather than the primary benchmark
  - Document generator limitations, including recency-based Open status and generated vendor price levels
  - Record the December 31, 2025 reference date for Open-order status
  - Explain the April 19, 2026 delivery-date tail

- [ ] **`DATA_DICTIONARY.md`**
  - Document the `dim_date` coverage through December 31, 2025
  - Explain that delivery dates extend through April 19, 2026
  - Clarify the date relationship and how delivery-date analysis avoids dropping valid records

- [ ] **Cross-document consistency check**
  - Confirm that key figures match across README, PROJECT_SPEC, DATA_DICTIONARY, DECISIONS, and SQL
  - Clearly distinguish observed results from assumptions and generated-data limitations

### 2. Excel Savings Opportunity Model

- [ ] Build `excel/savings_opportunity_model.xlsx` using `excel/excel_model_guide.md`
  - Load SQL exports using Power Query
  - Add editable Low / Base / High recovery assumptions
  - Build a savings opportunity analysis by vendor and product
  - Add a savings tracker that separates identified, approved, and realized savings
  - Create PivotTables for vendor, category, and opportunity analysis
  - Add a Checks sheet to reconcile Excel calculations against SQL results within $1
  - Clearly label the $17.3M figure as a theoretical price-gap ceiling, not guaranteed savings

**Completion criteria:** The workbook refreshes successfully, scenario assumptions are editable, and its key calculations reconcile to SQL.

---

## NEXT

### 3. Power BI Semantic Model

- [ ] Build the star schema using the cleaned SQL tables or approved analysis exports
- [ ] Create a dedicated measures table
- [ ] Implement DAX measures for core KPIs and time intelligence
- [ ] Configure date relationships without losing delivery records after December 31, 2025
- [ ] Validate filter behavior across dimensions and measures
- [ ] Implement row-level security only where the data model supports a meaningful Department- or Region-level access rule
- [ ] Test RLS with representative users or roles
- [ ] Publish to Power BI Service, subject to available account and licensing access

**Completion criteria:** The model produces consistent results under the intended filters, preserves the relevant date coverage, and passes the planned RLS tests.

### 4. Power BI Dashboard

Build three report pages.

**Page 1 — Executive Overview**
- Total ordered spend and monthly trend
- Completed versus Open spend context
- Vendor concentration
- Spend forecast
- Footnote explaining the most recent months of Completed-only spend

**Page 2 — Vendor Performance**
- On-Time Delivery by vendor
- Price-versus-on-time quadrants
- Vendor scorecard
- Vendor spend concentration
- Survivorship caveat: Open orders are not included in delivered-line performance metrics

**Page 3 — Cost & Procurement Opportunities**
- Price-gap opportunity by vendor and category
- Low / Base / High recovery scenarios
- Flagged vendor-product pairs
- Sensitivity analysis for products with at least three vendors
- Clear distinction between theoretical opportunity and assumed recoverable savings

### 5. UAT & Traceability

- [ ] Create `documentation/uat_plan.md`
- [ ] Map each stakeholder question to its KPI, report visual, and validation test
- [ ] Reconcile Power BI and Excel against SQL:
  - Completed spend: $499.65M
  - Distinct POs: 8,014
  - Active vendors: 41
  - On-Time Delivery: 75.8%
  - Theoretical price-gap ceiling: $17.3M
- [ ] Test slicers, filters, drill-through, and cross-highlighting
- [ ] Test RLS, if implemented
- [ ] Verify date behavior, including delivery records through April 19, 2026
- [ ] Verify the December 2025 end-of-data caveat
- [ ] Record test results, discrepancies, and resolutions

**Completion criteria:** Every major KPI and visual has a documented validation result, and material discrepancies are resolved or explained.

### 6. Executive Brief & Portfolio Presentation

- [ ] Create `documentation/executive_brief.md`
  - Business problem and analytical approach
  - Most important findings
  - Procurement opportunities and scenario assumptions
  - Vendor performance insights
  - Forecast and limitations
  - Practical recommendations

- [ ] Add a clear dashboard screenshot near the top of the README
- [ ] Update README project status, repository tree, and next steps after Excel and Power BI are complete
- [ ] Make the project easy to understand without requiring someone to read every SQL script

### 7. Final Documentation & Portfolio Audit

- [ ] Rewrite `DECISIONS.md` and `PROJECT_SPEC.md` in my own voice after I can explain the decisions and trade-offs
- [ ] Review all documentation for consistency and unnecessary technical detail
- [ ] Verify that every major finding can be traced to a SQL query, calculation, or explicit assumption
- [ ] Remove outdated task statuses and references to unfinished work
- [ ] Check repository organization, file names, instructions, and reproducibility
- [ ] Review the project as a hiring manager: can someone quickly understand the business problem, what I did, what I found, and why it matters?
- [ ] Lock Checkpoint 7: Final Portfolio Audit

---

## CARRY FORWARD — Important Analytical Guardrails

These are constraints to preserve while building the Excel model, Power BI report, and executive brief.

### Spend & Time Trends
- Use ordered spend (Completed + Open) for monthly spend trends.
- Footnote the last one or two months of Completed-only visuals because recent orders are more likely to remain Open.
- Do not interpret the December 2025 Completed-spend dip as a sudden business decline.
- Keep the forecast flat and describe the ±$1.7M as a rough historical error range, not a statistical confidence interval.
- Explain that the forecast assumes no trend, even though 2025 ordered spend was approximately 4.6% above 2024.
- Treat the forecast as exploratory: only 24 months of history and 12 holdout observations were available.

### Open-Order Aging
- Open status was assigned by the generator using order recency, not actual supplier behavior.
- Use December 31, 2025 as the primary reference date.
- Show April 19, 2026 as a sensitivity, not as a directly comparable operational snapshot.
- Label Open-order aging as illustrative wherever it appears.
- Do not present the overdue Open report as evidence of actual vendor backlog or performance.

### Pricing & Savings
- Do not present gross unfavorable PPV as achievable savings.
- Unfavorable PPV against the median is $22.05M, offset by $24.71M favorable PPV.
- Unfavorable PPV against `Standard_Cost` is $36.32M.
- Base savings are an assumed recovery scenario, not a forecast or commitment.
- Eleven of the 96 flagged pairs are on two-vendor products, representing approximately $2.74M of the theoretical ceiling.
- Show the three-or-more-vendor sensitivity separately: $14.6M ceiling and approximately $3.6M / $7.3M / $10.9M at 25% / 50% / 75% recovery.
- A vendor with a higher price index may also provide better delivery reliability. For example, Keystone has the largest price gap and 96.5% on-time delivery. Avoid recommending repricing without considering the full relationship.

### Vendor Performance & Scorecard
- Price and on-time performance are weakly correlated (r = 0.09); analyze them separately.
- Show the four price-versus-on-time quadrants.
- Delivery KPIs cover eligible Completed lines only. Open orders, including potentially late orders, are excluded. State this survivorship limitation.
- The scorecard weights (40 / 20 / 30 / 10) are judgment-based assumptions, not objective industry standards.
- Document the score direction, normalization method, and treatment of missing observations before presenting the score as a final ranking.
- Treat 2026 delivery months cautiously because their samples are small.

### Data Model & Generated-Data Limitations
- `dim_date` currently ends December 31, 2025, while delivery dates extend through April 19, 2026.
- Extend the date table or use a separate delivery-date approach. Do not silently lose valid delivery records.
- Before using `dim_date[Week]`, confirm its definition; it represents seven-day blocks beginning January 1, not ISO weeks.
- Software represents approximately 27.9% of spend, or roughly $70M annually. This is a generator setting and should not be treated as a real-world industry benchmark.
- The clean separation in vendor price levels is also a generator characteristic.
- Do not add inventory/MRP, contract compliance, maverick spend, OTIF, machine learning, or cloud-platform analysis without supporting data and an explicit scope change.

---

## DECIDED / PARKED

- `data/cleaned/` is not currently needed. Excel analysis exports are stored under `excel/data/`. Decide whether Power BI should connect directly to SQL Server or use approved exports during model development.
- Annual spend assumption of approximately $250M accepted, supported by $499.65M in Completed spend across the two-year analysis period.
- Primary PPV benchmark: product-level observed median across both years and all vendors. `Standard_Cost` is a cross-check.
- Forecast method: six-month moving average (`MA6`), selected using pooled backtest error across two origins.
- Out of scope without additional data or a regenerated dataset:
  - Inventory and MRP analysis
  - Contract compliance
  - Maverick-spend analysis
  - On-time-in-full (no received-quantity field)
  - Machine learning models
  - Cloud data platforms

