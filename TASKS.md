# TASKS — Active Queue

## COMPLETED
- [x] Business problem, scope, stakeholders, business questions
- [x] Data architecture (5-table star schema)
- [x] KPI definitions
- [x] Data-generation rules & data-quality strategy
- [x] Project workflow ("AI Operating System")
- [x] Build `python/generate_data.py`
- [x] Generate raw dataset
- [x] Inspect raw dataset (row counts, duplicates, nulls, invalid values, date
      ranges, distributions, relationship integrity, business realism)
- [x] Validate data-quality injection rates against targets
- [x] Validate business realism (department volume, dept→category affinity,
      vendor concentration, delivery variance, price variance)
- [x] Find and fix 2 generator bugs (impossible delivery dates; unrealistic
      Manufacturing line totals) — see DECISIONS.md
- [x] Sign-off on inspection report, including the ~$250M/yr total spend
      assumption (flagged as revisitable if it looks off during analysis)
- [x] Lock Checkpoint 2 (data generation)
- [x] Clarify KPI grain: delivery KPIs at PO-line level, PO Count as
      COUNT(DISTINCT PO_ID) — see DECISIONS.md
- [x] Load CSVs into SQL Server as `stg_` staging tables (all nvarchar)
- [x] `sql/01_data_quality.sql` — audit of the staging tables (duplicates,
      missing values, invalid values, formatting, invalid dates, PO_Line_ID
      collisions). Read-only; nothing is changed here.
- [x] `sql/02_data_cleaning.sql` — builds all five cleaned `dbo.` tables
      (fact + 4 dimensions) from staging. Re-runnable. Row counts verified:
      19,579 / 9 / 41 / 107 / 731.
- [x] Find and resolve PO_Line_ID collisions (9 cases) — see DECISIONS.md
- [x] Verify dimension tables clean, incl. zero orphan keys vs. the fact table
- [x] Remove CHANGELOG.md (redundant with DECISIONS.md and commit history)
- [x] GitHub profile: bio, profile README, portfolio landing page

## CURRENT
- [ ] `sql/03_spend_analysis.sql` — first JOINs and first KPIs: Total
      Procurement Spend, spend over time, spend by department and category

## NEXT
- [ ] `sql/04_vendor_performance.sql` — vendor spend share and concentration,
      On-Time Delivery %, Average Days Late (PO-line grain)
- [ ] `sql/05_pricing_analysis.sql` — price variance vs. product-level benchmark
- [ ] `sql/06_opportunity_analysis.sql` — pull the above into investigation
      candidates
- [ ] Power BI semantic model
- [ ] Dashboard (3 pages: Executive Overview, Vendor Performance, Cost &
      Procurement Opportunities)
- [ ] Findings & recommendations (must come from real analysis — not before)
- [ ] Final documentation polish (rewrite README.md and DECISIONS.md in my own
      voice once each part is genuinely understood)
- [ ] Final portfolio audit (Checkpoint 7)

## HOUSEKEEPING
- [ ] Update README.md: status section (SQL cleaning done), repo structure
      (remove CHANGELOG.md, list the actual sql/ files)
- [ ] Decide on `data/cleaned/`: export the 5 cleaned tables as CSVs, or
      remove the folder from the README tree
- [ ] Revisit the ~$250M/yr spend assumption once real spend analysis exists
- [ ] Before using dim_date[Week] for anything: confirm it isn't ISO weeks