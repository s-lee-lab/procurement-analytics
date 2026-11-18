# TASKS — Active Queue

## COMPLETED

- Business problem, scope, stakeholders, business questions
- Data architecture (5-table star schema)
- KPI definitions
- Data-generation rules & data-quality strategy
- Project workflow ("AI Operating System")
- Build `python/generate_data.py`
- Generate raw dataset
- Inspect raw dataset (row counts, duplicates, nulls, invalid values, date ranges, distributions, relationship integrity, business realism)
- Validate data-quality injection rates against targets
- Validate business realism (department volume, dept→category affinity, vendor concentration, delivery variance, price variance)
- Find and fix 2 generator bugs (impossible delivery dates; unrealistic Manufacturing line totals) — see DECISIONS.md
- Sign-off on inspection report, including the ~$250M/yr total spend assumption (flagged as revisitable if it looks off during analysis)
- Lock Checkpoint 2 (data generation)
- Clarify KPI grain: delivery KPIs at PO-line level, PO Count as COUNT(DISTINCT PO_ID) — see DECISIONS.md
- Load CSVs into SQL Server as `stg_` staging tables (all nvarchar)
- `sql/01_data_quality.sql` — audit of the staging tables (duplicates, missing values, invalid values, formatting, invalid dates, PO_Line_ID collisions). Read-only; nothing is changed here.
- `sql/02_data_cleaning.sql` — builds all five cleaned `dbo.` tables (fact + 4 dimensions) from staging. Re-runnable. Row counts verified: 19,579 / 9 / 41 / 107 / 731.
- Find and resolve PO_Line_ID collisions (9 cases) — see DECISIONS.md
- Verify dimension tables clean, incl. zero orphan keys vs. the fact table
- Remove CHANGELOG.md (redundant with DECISIONS.md and commit history)
- GitHub profile: bio, profile README, portfolio landing page
- `sql/03_spend_analysis.sql` — first JOINs and KPIs. Total completed spend $499.65M, 8,014 POs, 41 vendors; spend by year, month, department, category, subcategory; totals reconcile to the cent. Found the end-of-data artifact (Dec 2025 dip) — see DECISIONS.md
- `sql/04_vendor_performance.sql` — vendor spend share and concentration (top-10 share 56.8%, 19 vendors = 80%, HHI 439, 8 single-source products), On-Time Delivery % (75.8% overall) and Average Days Late at PO-line grain; Section 12 ages Open lines as of 2025-12-31 and 2026-04-19. Found the calendar-coverage gap (deliveries run to 2026-04-19, `dim_date` ends 2025-12-31) — see DECISIONS.md
- Open-order aging: Open status in the generator is assigned by order recency, not vendor or expected date, so the overdue report is illustrative, not a backlog finding (reasoning to be logged in DECISIONS.md, 2026-11-10)
- `sql/05_pricing_analysis.sql` — Purchase Price Variance (PPV) against a product-level median benchmark (Standard_Cost used as a cross-check). Vendor price index runs 0.75–1.18; no volume-discount pattern (0.999 / 1.007 / 0.983); 2025 prices about 3% above 2024 without changing the vendor ranking (year-adjusted check)
- `sql/06_opportunity_analysis.sql` — 96 flagged vendor-product pairs, $17.3M price-gap ceiling (3.47% of spend), low / base / high savings of $4.3M / $8.7M / $13.0M at assumed 25 / 50 / 75% recovery; on products with 3+ vendors the ceiling is $14.6M. Weighted vendor scorecard, price × on-time quadrants (5 vendors are above benchmark AND under 70% on-time: $89.8M, 18% of spend), tail spend, overdue-Open report, and export grids for Excel
- `sql/07_spend_forecast.sql` — monthly ordered-spend forecast, two-origin backtest, six-month average (ma6) selected: about $22.4M/month for Jan–Jun 2026, typical miss about $1.7M
- Job-posting review: gaps identified and folded into the plan (see DECISIONS.md, 2026-11-02)
- `excel/excel_model_guide.md` written; CSV exports from `06` saved in `excel/data/`
- README rewritten (findings first, first person, numbers verified against query results)

## CURRENT

- **Docs catch-up** (the analysis is ahead of the log):
  - DECISIONS.md: add entries for the Open-order aging finding (2026-11-10), pricing and benchmark choice, opportunity sizing and scorecard (including the 2-vendor sensitivity), and the forecast backtest
  - DECISIONS.md and `04_vendor_performance.sql`: correct "33.2%" to "34.9%" for spend held by the 15 vendors under 70% on-time (the vendor shares sum to 34.92%)
  - PROJECT_SPEC.md: Price Variance benchmark = product-level median across both years and all vendors (confirmed after inspection); add the generator-artifact limitations (Open status, vendor price levels); record the reference date (below)
  - DATA_DICTIONARY.md: add the `dim_date` coverage note
- **Build `excel/savings_opportunity_model.xlsx`** from `excel/excel_model_guide.md`: Power Query load, scenario inputs, savings tracker, PivotTables, and a Checks sheet that reconciles to the SQL results within $1

## NEXT

- **Power BI semantic model:** star schema, a dedicated measures table, DAX with time intelligence, row-level security (e.g., by Department or Region), publish to Power BI Service. Date table must cover delivery dates (see Carry Forward)
- **Dashboard** (3 pages):
  - Executive Overview: spend and trend (ordered spend, last-month footnote), concentration, forecast line
  - Vendor Performance: on-time by vendor, price × on-time quadrants, scorecard, survivorship caveat
  - Cost & Procurement Opportunities: price gap by vendor and category, Low / Base / High savings scenarios, flagged pairs
- **UAT & traceability** (`documentation/uat_plan.md`): table mapping each stakeholder question → KPI → visual → test; test log reconciling Power BI and Excel against the SQL totals ($499.65M, 8,014 POs, 41 vendors, 75.8% on-time, $17.3M ceiling); slicer/filter tests; RLS tests; known-limitation checks (Dec 2025 footnote)
- **One-page executive brief** (`documentation/executive_brief.md`) built from the findings, plus a dashboard screenshot near the top of the README
- Update README status, tree and "Next" list after Excel and Power BI exist
- Final documentation polish: rewrite DECISIONS.md and PROJECT_SPEC.md in my own voice once each part is genuinely understood
- Final portfolio audit (Checkpoint 7)

## CARRY FORWARD

- **Dashboard trend:** use ordered spend (Completed + Open) for trends, and footnote the last 1-2 months of any Completed-only visual (recent orders are still Open, so recent Completed spend looks low)
- **Reference date:** Open status was assigned as of 2025-12-31 (generator), while delivery dates run to 2026-04-19. Age Open lines as of 2025-12-31, show April 2026 as a sensitivity, and record this in PROJECT_SPEC.md
- **Open-order aging is illustrative:** overdue Open lines come from the generator's recency-based status odds, not vendor behavior. Label it that way wherever it appears, and list it under limitations
- **Open question (low priority):** vendor Open rates on older orders vary more than chance would give (chi-square 77.4, 40 df; range 1.7%–7.5%, pooled 4.4%). Search the generator for a status override and compare with vendor on-time %
- **Don't present gross unfavorable PPV as savings:** $22.05M (4.41% of spend) vs. the median is offset by $24.71M favorable; against Standard_Cost it is $36.32M (7.27%). Savings come only from the flagged pairs, as assumed recovery ranges
- **Median is a midpoint on 2-vendor products:** 11 of the 96 flagged pairs ($2.74M, about 16% of the ceiling) are on 2-vendor products. Show the 3+ vendor figure ($14.6M ceiling; $3.6M / $7.3M / $10.9M) as the conservative case
- **Price and on-time are uncorrelated** (r = 0.09). Score them separately and show the four quadrants. A vendor like Keystone (largest gap, 96.5% on-time) may be buying reliability: don't recommend repricing it blindly
- **Scorecard weights (40 / 20 / 30 / 10) and recovery rates (25 / 50 / 75%) are judgment calls.** State them as assumptions on the dashboard and in the brief
- **Forecast:** keep the line flat, show the ±$1.7M band as a rough range, and note it assumes no trend (2025 ran about 4.6% above 2024). Seasonality only repeats Jul–Dec, so use a seasonal method only if the horizon extends into H2
- **Power BI date table:** `dim_date` ends 2025-12-31. Extend it past 2026-04-19 (or keep deriving delivery month from the date) so delivery relationships don't silently drop rows (158 lines were dropped by the SQL inner join before this was fixed)
- **Survivorship caveat:** delivery KPIs only cover delivered lines, so late orders still Open count against no vendor. State this on the scorecard and the Vendor Performance page
- **2026 delivery months:** very small samples with low on-time rates (likely late-2025 orders slipping). Footnote or exclude from vendor trend visuals
- Limitations to carry into the brief: Software is 27.9% of spend (~$70M/yr), high for a ~1,000-person manufacturer, and the clean split in vendor price levels is unlikely in real data; both are generator settings
- Before using dim_date[Week] for anything: confirm it isn't ISO weeks

## DECIDED / PARKED

- `data/cleaned/`: skipped. For Excel, the CSV exports of the `06` results live in `excel/data/`. Decide at the Power BI step whether to connect to SQL Server directly or use CSVs.
- ~$250M/yr spend assumption: accepted. Spend analysis supports it ($499.65M over 2 years); the Software share is noted above.
- PPV benchmark: product-level median is primary; Standard_Cost is a cross-check (no unit-of-measure problems, no missing values; product medians sit up to 33% from Standard_Cost).
- Forecast method: six-month average (ma6), chosen on pooled backtest error across two origins, because the Jul–Dec holdout alone flattered seasonal methods.
- Not adding (no supporting data, and out of scope without regenerating): inventory/MRP analysis, contract compliance and maverick-spend analysis, on-time-in-full (no received-quantity field), ML models, cloud data platforms. Listed under limitations in the final writeup instead.