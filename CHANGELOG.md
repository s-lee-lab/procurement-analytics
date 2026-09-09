# CHANGELOG

## 2026-09-07
- Locked project requirements, architecture, KPI definitions, and workflow (Checkpoint 1).
- Built `python/generate_data.py` — generates the 5 raw CSVs per the locked star schema.
- First generation run flagged two logic bugs during inspection:
  - Delivery dates could precede order dates for short-lead-time products — fixed.
  - Manufacturing "Components" line totals could reach $2.5M+ due to independent
    high-end cost/quantity rolls colliding — fixed with a category line-value guardrail.
- Re-ran generator after fixes; full inspection passed (see `documentation/methodology.md`).
- Added `DECISIONS.md`, `TASKS.md`, `CHANGELOG.md`, `documentation/methodology.md`.
