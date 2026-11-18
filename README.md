# Procurement Spend & Vendor Performance Analytics

I'm moving from an operations and general-affairs background into analyst work in procurement, supply chain and BI, and I wanted a project that looks like the real work instead of a tutorial. This one takes two years of messy purchasing data for a fictional manufacturer, **Northstar Electronics** (about 1,000 employees, 41 vendors, roughly 19,700 purchase-order lines), and asks a question a procurement manager would ask: **where should we look first to cut cost or fix delivery problems?**

Everything here is built on synthetic data, so the numbers show the method, not real purchasing behavior. I've called out what that does and doesn't mean in the limitations at the bottom. Throughout, I treat results as investigation candidates, not verdicts.

**If you only have two minutes:** read "What I found" below, then skim `DECISIONS.md`, where I log every bug, correction and judgment call.

## What I found

- **Spend is moderately concentrated, not dominated.** Completed spend was $499.65M over 2024–2025 across 8,014 POs. The top 10 vendors hold 56.8%, and 19 of the 41 cover 80%. Ordered spend (completed plus open orders) grew 4.6%, from $260.2M to $272.2M.
- **On-time delivery varies far more by vendor than by anything else I checked.** 75.8% of PO lines arrived on time, and late lines averaged 12.6 days late. On-time rates range from 52.8% to 97.2% by vendor, against 66–82% by category and 72–79% by department. I haven't tested that statistically. The 15 vendors under 70% on-time hold 34.9% of spend.
- **Vendors price the same products very differently, and volume doesn't explain it.** Against the median price for each product, vendor price levels run from 0.75× to 1.18×. Larger orders aren't priced lower (index of 0.999, 1.007 and 0.983 across quantity thirds), and the roughly 3% rise in prices from 2024 to 2025 didn't change how vendors compare.
- **The price gap is worth looking at, with caveats.** 96 vendor-product pairs are priced more than 5% above the product median, and the dollars paid above that median come to $17.3M over two years (3.5% of spend). If 25%, 50% or 75% of the gap were recovered, that's $4.3M, $8.7M or $13.0M. Those recovery rates are my assumptions, not findings. Counting only products with three or more vendors, where the median is a real market reference, the gap is $14.6M and the range is $3.6M to $10.9M.
- **Five vendors are both expensive and unreliable:** Lakeside Cloud, Lighthouse Industrial, Pinnacle Software, Anchor Solutions and Ironclad Professional Services. They hold $89.8M of spend (18%) and about $8.2M of the price gap, so they're where I'd start. The vendor with the largest single gap, Keystone Manufacturing ($4.8M), is on time 96.5% of the time, so its premium may be buying reliability.
- **A simple forecast: about $22.4M a month for Jan–Jun 2026.** Monthly spend swings a lot, grew about 4.6% year over year, and shows no repeatable seasonal pattern in the first half of the year, so a six-month average beat the seasonal methods in a backtest. The typical miss was about $1.7M a month.

## What this shows

- **SQL beyond simple queries:** staging, cleaning, CTEs, window functions and percentiles, with a reconciliation check on every result (totals tie to the cent).
- **Judgment about data:** I separate data errors (cleaned) from business anomalies (kept, because they may be the finding), and I log my mistakes and corrections instead of hiding them.
- **Procurement fluency:** spend concentration, on-time delivery, purchase price variance, a supplier scorecard, savings sizing with stated assumptions, and a forecast with an honest backtest.
- **Writing for decision-makers:** every result is framed as something to investigate, with its limits next to it.
- **Not built yet, so not claimed:** the Excel/Power Query savings model, the Power BI dashboard (DAX, row-level security) and the UAT plan are still ahead of me.

## How I got there

I loaded the raw data as text so nothing was altered on import, then audited it in SQL before trusting it. I found 128 duplicated rows, 9 reused PO line IDs, and invalid values (negative or zero prices and quantities, impossible dates). Duplicates and ID collisions were removed, and invalid values were kept in the tables but excluded in each query, with the counts reported. I also caught two bugs in my own data generator before analyzing anything, and a calendar-table gap that silently dropped 158 delivery lines from an early join. The reasoning behind each decision, including the corrections, is in `DECISIONS.md`.

## Where it stands

**Done:** requirements and KPI definitions, data generation and validation, SQL cleaning, and all the SQL analysis (spend, vendor performance, pricing, opportunity sizing and scorecard, and the forecast).

**Next:**
1. An Excel savings model with Power Query, scenario inputs and a savings tracker (build guide is in `excel/`)
2. A Power BI dashboard with a measures table and row-level security
3. A UAT plan that reconciles the dashboard and the workbook to the SQL results
4. A one-page executive brief

## Repo structure

```
procurement-analytics/
├── README.md
├── PROJECT_SPEC.md        business problem, scope, stakeholders, KPIs
├── DATA_DICTIONARY.md     tables, columns, definitions, relationships
├── DECISIONS.md           decision log, including bugs found and fixed
├── TASKS.md               active task queue
├── data/
│   └── raw/               generator output (5 CSVs)
├── sql/
│   ├── 01_data_quality.sql         audit of the raw staging tables (read-only)
│   ├── 02_data_cleaning.sql        builds the cleaned tables (safe to re-run)
│   ├── 03_spend_analysis.sql       spend KPIs, trends, department and category breakdowns
│   ├── 04_vendor_performance.sql   vendor concentration, on-time delivery, days late
│   ├── 05_pricing_analysis.sql     price variance against product medians (PPV)
│   ├── 06_opportunity_analysis.sql savings sizing, vendor scorecard, quadrants, exports
│   └── 07_spend_forecast.sql       monthly spend forecast with a two-origin backtest
├── python/
│   └── generate_data.py
├── excel/
│   ├── excel_model_guide.md        build guide for the savings model
│   └── data/                       CSV exports from 06 (vendor scorecard, flagged pairs)
├── powerbi/                (not yet populated)
└── documentation/
    └── methodology.md     full raw-data validation report
```

## Reproducing the results

1. Import the 5 CSVs from `data/raw/` into SQL Server as `stg_` tables, all columns as text.
2. Run `sql/01_data_quality.sql` to see the data-quality issues in the raw data.
3. Run `sql/02_data_cleaning.sql` to build the cleaned `dbo.` tables: 19,579 fact rows (from 19,716 raw) plus 4 dimension tables. It's safe to re-run.
4. Run `sql/03` and `sql/04` for spend and vendor performance. They read only from the cleaned tables.
5. Run `sql/05`, `sql/06` and `sql/07`. Each one builds its own temporary tables, so run each in a single query window from top to bottom. `06` ends with two export grids, which I saved as the CSVs in `excel/data/`.

One thing to know: orders stop on 2025-12-31, but deliveries run into 2026, past the end of the date table. Delivery KPIs derive the delivery month from the date itself rather than joining to the date table (see `DECISIONS.md`, 2026-11-02).

## Limitations

- **Synthetic data.** The scale of spend (about $250M a year), the category mix (Software is about 28% of spend) and the clean split in vendor price levels come from generator settings, not real company behavior. Real data would be messier. The point is the method.
- **The savings ranges are assumptions.** The price gap is dollars paid above a product's median price. It isn't confirmed overpayment, because contract terms, specs and service levels can all explain a difference. The 25 / 50 / 75% recovery rates are my choices. On products with only two vendors, the median is just a midpoint, so one vendor always looks expensive.
- **Delivery risk has no dollar value,** because the data has no cost-of-delay field. On-time delivery is measured only on delivered lines, so late orders still open count against no vendor. There's no received-quantity field, so I can report on-time but not on-time-in-full.
- **Order status is a generator artifact.** The synthetic data assigns "Open" mostly by how recent an order is. The overdue-open-order report in `06` is a demonstration of the method, not a finding about a backlog.
- **The forecast is a method demonstration.** There are only 24 monthly data points, it assumes no trend (2025 ran about 4.6% above 2024, so it may run low), and I chose a method after seeing its backtest, which flatters it slightly.

See `DECISIONS.md` and `documentation/methodology.md` before trusting any numbers from `data/raw/`. Every bug, correction and judgment call is logged there rather than quietly patched.