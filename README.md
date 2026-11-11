# Procurement Spend & Vendor Performance Analytics

A BI case study for a fictional company, **Northstar Electronics**, analyzing procurement spending, supplier performance, and purchasing behavior to identify opportunities for cost control and operational improvement.

**Stack:** SQL Server → Power BI (Python used only to generate a realistic, intentionally-imperfect synthetic dataset). An Excel/Power Query savings model is planned alongside Power BI.

## Status

- 🟢 Requirements, architecture, KPI methodology — locked
- 🟢 Raw dataset generated & independently validated — see `documentation/methodology.md`
- 🟢 SQL data-quality audit & cleaning — complete (raw staging tables → cleaned star schema)
- 🟡 SQL analysis — in progress (spend and vendor performance done; pricing and opportunity analysis next)
- ⚪ Excel savings model — not started
- ⚪ Power BI — not started

## Repo structure

```
procurement-analytics/
├── README.md
├── PROJECT_SPEC.md        business problem, scope, stakeholders, KPIs
├── DATA_DICTIONARY.md     tables, columns, definitions, relationships
├── DECISIONS.md           decision log, including bugs found & fixed
├── TASKS.md               active task queue
├── data/
│   └── raw/               generator output (5 CSVs)
├── sql/
│   ├── 01_data_quality.sql        audit of the raw staging tables (read-only)
│   ├── 02_data_cleaning.sql       builds the cleaned tables (safe to re-run)
│   ├── 03_spend_analysis.sql      spend KPIs, trends, department/category breakdowns
│   └── 04_vendor_performance.sql  vendor concentration, on-time delivery, days late
├── python/
│   └── generate_data.py
├── excel/                  (not yet populated)
├── powerbi/                (not yet populated)
└── documentation/
    └── methodology.md     full raw-data validation report
```

## Reproducing the database

1. Import the 5 CSVs from `data/raw/` into SQL Server as `stg_` tables (all columns as text, so messy values load without being altered).
2. Run `sql/01_data_quality.sql` to see the data-quality issues found in the raw data.
3. Run `sql/02_data_cleaning.sql` to build the cleaned `dbo.` tables: 19,579 fact rows (from 19,716 raw) plus 4 dimension tables.
4. Run `sql/03_spend_analysis.sql` for the spend analysis. It only reads from the cleaned tables.
5. Run `sql/04_vendor_performance.sql` for vendor concentration and delivery performance. It also only reads from the cleaned tables.

Note: orders stop on 2025-12-31, but deliveries run into 2026, past the end of `dim_date`. Delivery KPIs therefore derive the delivery month from the date itself instead of joining delivery dates to `dim_date` (see `DECISIONS.md`, 2026-11-02).

See `DECISIONS.md` and `documentation/methodology.md` before trusting any numbers from `data/raw/` — two generator bugs were found and fixed during inspection, and a further data-quality issue (reused PO line IDs) was found and resolved during cleaning. All of it is documented there rather than silently patched.