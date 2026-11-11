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
- Update README.md (status, repo structure, reproduction steps)
- `sql/03_spend_analysis.sql` — first JOINs and KPIs. Total completed spend $499.65M, 8,014 POs, 41 vendors; spend by year, month, department, category, subcategory; totals reconcile to the cent. Found the end-of-data artifact (Dec 2025 dip) — see DECISIONS.md
- `sql/04_vendor_performance.sql` — vendor spend share and concentration (top-10 share 56.8%, 19 vendors = 80%, HHI 439, 8 single-source products), On-Time Delivery % (75.8% overall) and Average Days Late at PO-line grain. Found the calendar-coverage gap (deliveries run to 2026-04-19, `dim_date` ends 2025-12-31) — see DECISIONS.md. Complete except Section 12's results (see CURRENT).
- README refreshed to match (status, tree, reproduction step 5)

## CURRENT

- Finish `04_vendor_performance.sql` Section 12 (2026-04-19 delivery results)
- `sql/05_pricing_analysis.sql` — price variance vs. product-level benchmark. Report it as Purchase Price Variance (PPV): (actual price − benchmark) × quantity, in dollars, by vendor, category, and product

## NEXT

*Existing plan:*
- `sql/06_opportunity_analysis.sql` — pull the above into investigation candidates
- Power BI semantic model
- Dashboard (3 pages: Executive Overview, Vendor Performance, Cost & Procurement Opportunities)
- Findings & recommendations (must come from real analysis — not before)
- Final documentation polish (rewrite README.md and DECISIONS.md in my own voice once each part is genuinely understood)
- Final portfolio audit (Checkpoint 7)

*Added after the job-posting review (see DECISIONS.md, 2026-11-02) — each one extends a planned step rather than adding a new project:*
- **In `06_opportunity_analysis.sql`:** size each opportunity in dollars as a low / base / high range with the assumptions written down (price leakage from 05, vendor consolidation, tail spend)
- **In `06_opportunity_analysis.sql`:** past-due Open lines exception report (Open lines past Expected_Delivery_Date as of the snapshot date)
- **In `06_opportunity_analysis.sql`:** supplier scorecard — weighted composite of on-time %, days late, price variance, and spend concentration, with the weights documented
- `sql/07_spend_forecast.sql` — simple monthly spend forecast (baseline method) with a holdout backtest; report MAPE and bias. Only 24 monthly points, so keep the method simple and say so
- `excel/savings_opportunity_model.xlsx` — Power Query load of a cleaned export, PivotTables, scenario inputs, and a savings tracker table. This makes the "Excel/Power Query" part of the stack real
- **Power BI semantic model:** star schema, a dedicated measures table, DAX with time intelligence, row-level security (e.g., by Department or Region), publish to Power BI Service. Date table must cover delivery dates (see Carry Forward)
- **UAT & traceability** (`documentation/uat_plan.md`): table mapping each stakeholder question → KPI → visual → test; test log reconciling Power BI and Excel against the SQL totals ($499.65M, 8,014 POs, 41 vendors, 75.8% on-time); slicer/filter tests; RLS tests; known-limitation checks (Dec 2025 footnote)
- One-page executive brief (`documentation/executive_brief.md`) built from the findings, plus 2-3 headline findings and a dashboard screenshot at the top of the README

## CARRY FORWARD (from the spend and vendor analysis)

- Dashboard: flag or footnote the last 1-2 months of trend visuals (Open orders not yet delivered make recent Completed spend look low), and show Open spend as pipeline
- Operational analysis: about $12.3M of 2024 orders are still Open at the end of 2025 — worth checking against Expected_Delivery_Date (not a finding yet)
- Limitations writeup: Software is 27.9% of spend (~$70M/yr), high for a ~1,000-person manufacturer; likely a generator setting, same family as the ~$250M/yr assumption
- Before using dim_date[Week] for anything: confirm it isn't ISO weeks
- **Snapshot date:** deliveries run to 2026-04-19, so the data's real snapshot is later than the last order date (2025-12-31). Pick one snapshot date, record it in PROJECT_SPEC.md, and use it everywhere (Open-order aging, past-due report, dashboard footnotes)
- **Open-order aging:** if the snapshot is ~April 2026, Open lines from Dec 2025 (387 lines) are about four months old. Check them against Expected_Delivery_Date before the dashboard footnote says they're simply "not yet delivered"
- **Power BI date table:** `dim_date` ends 2025-12-31. Extend it past 2026-04-19 (or keep deriving delivery month from the date) so delivery relationships don't silently drop rows (158 lines were dropped by the SQL inner join before this was fixed)
- **Survivorship caveat:** delivery KPIs only cover delivered lines, so late orders still Open count against no vendor. State this on the scorecard and the Vendor Performance page
- **2026 delivery months:** very small samples with low on-time rates (likely late-2025 orders slipping). Footnote or exclude from vendor trend visuals
- Update PROJECT_SPEC.md and DATA_DICTIONARY.md with the snapshot date and the `dim_date` coverage note

## DECIDED / PARKED

- `data/cleaned/`: skipped for now (scripts + raw CSVs rebuild everything). Revisit when building the Excel model or Power BI; if exporting CSVs, add a `cleaned/` line back to the README tree and one sentence under "Reproducing the database".
- ~$250M/yr spend assumption: accepted. Spend analysis supports it ($499.65M over 2 years); the Software share is noted above.
- Not adding (no supporting data, and out of scope without regenerating): inventory/MRP analysis, contract compliance and maverick-spend analysis, ML models, cloud data platforms. Listed under limitations in the final writeup instead.