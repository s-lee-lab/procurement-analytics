# Procurement Spend & Vendor Performance Analytics

A BI case study for a fictional company, **Northstar Electronics**, analyzing
procurement spending, supplier performance, and purchasing behavior to
identify opportunities for cost control and operational improvement.

**Stack:** Excel/Power Query → SQL → Power BI (Python used only to generate a
realistic, intentionally-imperfect synthetic dataset).

## Status
🟢 Requirements, architecture, KPI methodology — locked
🟢 Raw dataset generated & independently validated — see `documentation/methodology.md`
🟡 Data-generation checkpoint — pending sign-off (see TASKS.md)
⚪ SQL — not started
⚪ Power BI — not started

## Repo structure
```
procurement-analytics/
├── README.md
├── PROJECT_SPEC.md        business problem, scope, stakeholders, KPIs
├── DATA_DICTIONARY.md     tables, columns, definitions, relationships
├── DECISIONS.md           decision log, including bugs found & fixed
├── TASKS.md               active task queue
├── CHANGELOG.md
├── data/
│   ├── raw/               generator output (5 CSVs)
│   └── cleaned/           (SQL cleaning output — not yet populated)
├── sql/                   (not yet populated)
├── python/
│   └── generate_data.py
├── powerbi/                (not yet populated)
└── documentation/
    └── methodology.md     full raw-data validation report
```

See `DECISIONS.md` and `documentation/methodology.md` before trusting any
numbers from `data/raw/` — two generator bugs were found and fixed during
inspection; they're documented there rather than silently patched.
