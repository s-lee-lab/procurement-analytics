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

## CURRENT
- [ ] **Your review/sign-off on the inspection report** (`documentation/methodology.md`),
      specifically the ~$250M/yr total spend assumption
- [ ] Lock Checkpoint 2 (data generation)

## NEXT
- [ ] Load into SQL Server / staging
- [ ] Create staging tables
- [ ] `sql/01_data_quality.sql` — quantify and (separately) clean the injected
      data-quality issues, leaving business anomalies untouched
- [ ] `sql/02_spend_analysis.sql`
- [ ] `sql/03_vendor_performance.sql`
- [ ] `sql/04_pricing_analysis.sql`
- [ ] `sql/05_opportunity_analysis.sql`
- [ ] Power BI semantic model
- [ ] Dashboard (3 pages)
- [ ] Findings & recommendations
- [ ] Final documentation
- [ ] Final portfolio audit (Checkpoint 7)
