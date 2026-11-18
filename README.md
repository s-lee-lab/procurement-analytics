# Procurement Spend & Vendor Performance Analytics

I'm moving from an operations and general-affairs background into analyst roles in procurement, supply chain, and BI. I wanted a portfolio project that felt closer to the work an analyst might actually do than a step-by-step tutorial.

This project uses two years of synthetic purchasing data for a fictional manufacturer, **Northstar Electronics**: roughly 1,000 employees, 41 vendors, and 19,700 purchase-order lines.

The business question is straightforward: **Where should procurement look first to reduce costs or improve supplier delivery performance?**

The data is synthetic, so the numbers demonstrate the analytical approach, not real purchasing behavior. I've called out the limitations throughout and treated the findings as starting points for investigation, not conclusions about actual suppliers.

**If you only have two minutes:** Start with "What I found" below, then look at `DECISIONS.md` for the reasoning behind the data-cleaning choices, corrections, and analytical assumptions.

## What I found

- **Spend is moderately concentrated, but not dominated by a handful of vendors.** Completed spend totaled $499.65M across 8,014 POs in 2024–2025. The top 10 vendors account for 56.8% of spend, while 19 of the 41 vendors account for 80%. Ordered spend, including both Completed and Open orders, increased 4.6% year over year, from $260.2M to $272.2M.

- **On-time delivery varies considerably across vendors.** Overall On-Time Delivery was 75.8% among Completed PO lines with valid expected and actual delivery dates. Late lines averaged 12.6 days past the expected date. Vendor on-time rates ranged from 52.8% to 97.2%, compared with 66–82% across categories and 72–79% across departments. I haven't tested whether those differences are statistically significant. The 15 vendors below 70% on-time account for 34.9% of spend.

- **Vendors charge different prices for the same products, and larger order quantities don't appear to explain the differences.** Vendor price indexes range from 0.75 to 1.18 relative to each product's median observed price. Across quantity thirds, the price indexes were 0.999, 1.007, and 0.983. I didn't find evidence of a consistent volume-discount pattern. Prices were approximately 3% higher in 2025 than in 2024, but the year-adjusted comparison did not materially change vendor rankings.

- **The price differences create opportunities worth investigating, not guaranteed savings.** I flagged 96 vendor-product pairs priced more than 5% above their product median, with at least 10 completed lines per pair. The resulting theoretical price-gap ceiling is $17.3M over two years, or 3.5% of Completed spend. Recovering 25%, 50%, or 75% of that gap would represent approximately $4.3M, $8.7M, or $13.0M. Those recovery rates are assumptions, not measured outcomes. Restricting the analysis to products with at least three vendors reduces the theoretical gap to $14.6M, with scenario estimates of $3.6M, $7.3M, and $10.9M.

- **Five vendors stand out when price and delivery performance are considered together.** Lakeside Cloud, Lighthouse Industrial, Pinnacle Software, Anchor Solutions, and Ironclad Professional Services are above the product-price benchmark and below 70% on-time. Together, they represent $89.8M in spend (18%) and approximately $8.2M in price-gap opportunity. They're where I'd start investigating. Keystone Manufacturing has the largest individual price gap at approximately $4.8M, but its on-time rate is 96.5%. That premium may reflect something worth understanding before recommending a price reduction.

- **A simple forecast puts monthly ordered spend at approximately $22.4M for January–June 2026.** I compared methods using two six-month backtest periods. The six-month moving average (MA6) had the best pooled error across those two tests. Its typical monthly miss was about $1.7M. With only 24 months of data, I treat this as a demonstration of forecasting and backtesting rather than a reliable long-term projection.

## What this shows

- **SQL and data preparation:** I used staging tables, data-quality audits, cleaning logic, CTEs, joins, window functions, and percentile calculations. I also built reconciliation checks so the reported totals tie back to the underlying data.
- **Judgment about data quality:** I separated obvious data errors from unusual business values. I corrected duplicates and identifier collisions, but retained questionable prices, quantities, and dates where appropriate so their impact could be handled explicitly in the analysis.
- **Procurement analysis:** I explored spend concentration, delivery performance, purchase price variance, supplier comparisons, opportunity sizing, and forecasting.
- **Communicating uncertainty:** I distinguish observed results from assumptions and generated-data artifacts. A price gap is not automatically a savings opportunity, and a late-delivery rate is not the whole picture of supplier performance.
- **What I'm building next:** The Excel/Power Query savings model, Power BI dashboard, and UAT plan are not complete yet, so I'm not presenting them as finished work.

## How I got there

I started by loading the raw CSVs into SQL Server as text so that the import process wouldn't silently change the source values. Before calculating any KPIs, I audited the staging tables for duplicates, missing values, invalid values, formatting problems, date issues, and key collisions.

The initial data contained 128 exact duplicate rows and nine reused purchase-order line IDs. I resolved those issues during cleaning, reducing the fact table from 19,716 raw rows to 19,579 cleaned rows.

I also found two problems in my own data generator: impossible delivery dates and unrealistic Manufacturing line totals. I fixed those before moving into the analysis.

Not every questionable value was deleted. For example, zero or negative quantities and prices remain in the cleaned data but are excluded from spend calculations. That keeps the underlying issues visible while preventing them from distorting the KPIs.

One other issue took some investigation: the date dimension ended on December 31, 2025, but delivery dates extended through April 19, 2026. An early SQL join dropped 158 valid delivery records. I corrected the delivery analysis to derive the delivery period directly from the actual delivery date.

I documented the reasoning behind these choices, including mistakes and corrections, in `DECISIONS.md`.

## Where it stands

**Completed**
- Business requirements, scope, and KPI definitions
- Synthetic data generation and validation
- SQL staging, data-quality auditing, and cleaning
- Spend, vendor performance, and pricing analysis
- Procurement opportunity sizing and vendor comparison analysis
- Two-origin forecast backtest
- Initial Excel model guide and SQL analysis exports

**Still in progress**
1. Reconcile the remaining documentation and methodology details.
2. Build an Excel savings model with Power Query, editable recovery assumptions, and a savings tracker.
3. Build a Power BI semantic model and dashboard with DAX measures and tested row-level security.
4. Create a UAT plan to reconcile the workbook and dashboard against SQL.
5. Write a one-page executive brief and complete the final portfolio review.

## Repository structure

```text
procurement-analytics/
├── README.md
├── PROJECT_SPEC.md          business problem, scope, stakeholders, KPIs
├── DATA_DICTIONARY.md       tables, columns, definitions, relationships
├── DECISIONS.md             decision log, including bugs found and fixed
├── TASKS.md                 active task queue
├── data/
│   └── raw/                 generator output (5 CSVs)
├── sql/
│   ├── 01_data_quality.sql
│   ├── 02_data_cleaning.sql
│   ├── 03_spend_analysis.sql
│   ├── 04_vendor_performance.sql
│   ├── 05_pricing_analysis.sql
│   ├── 06_opportunity_analysis.sql
│   └── 07_spend_forecast.sql
├── python/
│   └── generate_data.py
├── excel/
│   ├── excel_model_guide.md
│   └── data/                CSV exports from the SQL analysis
├── powerbi/                 planned dashboard and semantic model
└── documentation/
    └── methodology.md       raw-data validation report
```

## Reproducing the results

1. Import the five CSVs from `data/raw/` into SQL Server as `stg_` tables, with all columns initially stored as text.
2. Run `sql/01_data_quality.sql` to inspect data-quality issues in the raw staging tables.
3. Run `sql/02_data_cleaning.sql` to build the cleaned `dbo.` tables: 19,579 fact rows and four dimension tables. The script is safe to re-run.
4. Run `sql/03_spend_analysis.sql` and `sql/04_vendor_performance.sql` for spend and supplier performance analysis.
5. Run `sql/05_pricing_analysis.sql`, `sql/06_opportunity_analysis.sql`, and `sql/07_spend_forecast.sql`. Each script builds its own temporary tables, so run each one from top to bottom in a single query window. The opportunity analysis produces export grids that are saved under `excel/data/`.

A date detail worth knowing: purchase orders stop on December 31, 2025, but delivery dates extend through April 19, 2026. The current `dim_date` ends on December 31, 2025. Delivery KPIs therefore derive the delivery period directly from the delivery date rather than relying on a join to that date dimension. See `DECISIONS.md` for the original issue and correction.

## Limitations

- **Synthetic data:** The annual spend scale, category mix, and vendor price patterns come from generator settings. For example, Software accounts for approximately 27.9% of spend, or around $70M annually. That's a characteristic of this dataset, not an industry benchmark.
- **Price differences aren't automatically overpayments:** The median is a useful comparison point, but it doesn't account for every difference in specifications, contract terms, service levels, or purchasing conditions. The recovery scenarios are assumptions. For products with only two vendors, the median is simply the midpoint between their observed prices.
- **The price-gap ceiling isn't a savings commitment:** It measures dollars paid above the selected product-level median for the flagged pairs. The amount that could realistically be recovered would require further investigation and negotiation.
- **Delivery performance has a survivorship limitation:** On-time delivery is calculated from eligible Completed lines with valid expected and actual delivery dates. Open orders, including potentially late orders, are excluded from that calculation. There is no received-quantity field, so I can measure on-time delivery but not on-time-in-full.
- **Open-order aging is illustrative:** The generator assigns Open status largely based on order recency, not actual supplier behavior. The overdue Open-order analysis demonstrates the method but should not be interpreted as a real backlog or vendor-performance finding.
- **The forecast is exploratory:** There are only 24 monthly observations. MA6 assumes no trend, even though ordered spend increased approximately 4.6% in 2025. I also selected the method after reviewing its backtest performance, which introduces selection bias. The approximately $1.7M typical miss is a rough historical error measure, not a statistical confidence interval.
- **The vendor scorecard is assumption-driven:** Its weights and scoring choices are judgment calls. The normalization direction and treatment of missing observations need to be fully documented before the scorecard is treated as a validated vendor ranking.

The project is meant to show how I approach a purchasing-data problem: understand the business question, inspect the data before trusting it, build and validate the analysis, and communicate what the results can—and cannot—tell us. `DECISIONS.md` and `documentation/methodology.md` provide the supporting detail behind the analysis.