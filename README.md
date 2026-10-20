# Procurement Spend & Vendor Performance Analytics

A BI case study for a fictional company, **Northstar Electronics**, analyzing
procurement spending, supplier performance, and purchasing behavior to
identify opportunities for cost control and operational improvement.

**Stack:** Excel/Power Query → SQL → Power BI (Python used only to generate a
realistic, intentionally-imperfect synthetic dataset).

## Status
🟢 Requirements, architecture, KPI methodology — locked
🟢 Raw dataset generated & independently validated — see `documentation/methodology.md`
🟢 SQL data-quality audit & cleaning — complete (raw staging tables → cleaned star schema)
🟡 SQL analysis — next up (spend analysis first)
⚪ Power BI — not started

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
│   ├── 01_data_quality.sql    audit of the raw staging tables (read-only)
│   └── 02_data_cleaning.sql   builds the cleaned tables (safe to re-run)
├── python/
│   └── generate_data.py
├── powerbi/                (not yet populated)
└── documentation/
    └── methodology.md     full raw-data validation report
```

## Reproducing the database
1. Import the 5 CSVs from `data/raw/` into SQL Server as `stg_` tables
   (all columns as text, so messy values load without being altered).
2. Run `sql/01_data_quality.sql` to see the data-quality issues found in
   the raw data.
3. Run `sql/02_data_cleaning.sql` to build the cleaned `dbo.` tables:
   19,579 fact rows (from 19,716 raw) plus 4 dimension tables.

See `DECISIONS.md` and `documentation/methodology.md` before trusting any
numbers from `data/raw/` — two generator bugs were found and fixed during
inspection, and a further data-quality issue (reused PO line IDs) was found
and resolved during cleaning. All of it is documented there rather than
silently patched.