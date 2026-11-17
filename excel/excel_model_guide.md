# Excel savings model: build guide

Workbook: `excel/savings_opportunity_model.xlsx`
Sources: `excel/data/vendor_scorecard.csv` (06 Section 7a, 41 rows) and `excel/data/flagged_pairs.csv` (06 Section 7b, 96 rows).

**Purpose:** turn the SQL price-leakage findings into a scenario model and savings tracker a procurement analyst could actually use. All dollar figures are two-year totals on synthetic data. The savings ranges are assumptions, not findings.

**Conventions:** yellow fill = input you can change; grey fill = formula; every formula uses named ranges or structured table references, never typed-in numbers.

---

## 1. Load the data with Power Query

For each CSV: **Data > Get Data > From Text/CSV > Transform Data**. Load as a **Table** (not a PivotTable) and name the tables `tblVendors` and `tblPairs`.

Steps to apply in the Power Query editor (each shows up in the Applied Steps list, which is the skill being demonstrated):
1. Confirm column types: text columns as Text; `spend`, `gap_*`, `price_index`, `*_pct`, `avg_days_late`, `composite_score` as Decimal; `lines` and `flagged_products` as Whole Number.
2. Trim and clean all text columns (Transform > Format > Trim).
3. `tblPairs` only: add a custom column `Key` = `[Vendor_Name] & " | " & [Product_Name]` (unique per row; verify with Group By that no key appears twice).
4. `tblVendors` only: add a custom column `Spend $M` = `[spend] / 1000000`.
5. Rename the queries `Vendors` and `Pairs`. Set **Data > Queries & Connections > Properties > Refresh data when opening the file** to off. The CSVs are static exports.

## 2. Sheet layout

| Sheet | Contents |
|---|---|
| `README` | Purpose, source files, assumptions, limitations (below), refresh instructions |
| `Inputs` | Scenario inputs (yellow) and named ranges |
| `Vendors` | `tblVendors` (Power Query output) |
| `Pairs` | `tblPairs` (Power Query output) |
| `Tracker` | Savings tracker table `tblTracker` |
| `Summary` | Scenario results, PivotTables, chart |
| `Checks` | Reconciliation to the SQL results |

## 3. Inputs sheet (named ranges)

| Name | Value | Meaning |
|---|---|---|
| `rate_low` | 25% | Share of the price gap assumed recovered, low case |
| `rate_base` | 50% | Base case |
| `rate_high` | 75% | High case |
| `scenario` | Base | Dropdown (Data > Data Validation > List: Low, Base, High) |
| `rate_selected` | formula | `=CHOOSE(MATCH(scenario,{"Low","Base","High"},0), rate_low, rate_base, rate_high)` |
| `reliable_cutoff` | 85 | Vendors at or above this on-time % are treated as "reliable" in the reliability-adjusted case |
| `years_in_data` | 2 | Used to annualize |

## 4. Tracker sheet

Create `tblTracker` with one row per flagged pair. Fill the `Key` column once by copying `tblPairs[Key]` as values (Power Query output can be overwritten on refresh, so the tracker is a separate regular table; the lookups keep it linked).

| Column | Type | Formula / rule |
|---|---|---|
| `Key` | text | pasted values from `tblPairs[Key]` |
| `Vendor` | formula | `=XLOOKUP([@Key], tblPairs[Key], tblPairs[Vendor_Name])` |
| `Product` | formula | same pattern, `tblPairs[Product_Name]` |
| `Category` | formula | same pattern, `tblPairs[Product_Category]` |
| `Gap to Median ($)` | formula | `=XLOOKUP([@Key], tblPairs[Key], tblPairs[gap_to_median])` |
| `Vendor On-Time %` | formula | `=XLOOKUP([@Key], tblPairs[Key], tblPairs[vendor_on_time_pct])` |
| `Expected Savings ($)` | formula | `=[@[Gap to Median ($)]] * rate_selected` |
| `Owner` | input | free text |
| `Status` | input | dropdown: Not started, Negotiating, Agreed, Realized, Rejected |
| `Realized Savings ($)` | input | number |
| `Variance ($)` | formula | `=[@[Realized Savings ($)]] - [@[Expected Savings ($)]]` |
| `Notes` | input | free text |

Add conditional formatting on `Status` (one colour per value) and sort by `Gap to Median ($)` descending so the biggest opportunities sit on top.

## 5. Summary sheet

Scenario block (all formulas):

| Metric | Formula | Expected (from SQL) |
|---|---|---|
| Gap ceiling ($) | `=SUM(tblPairs[gap_to_median])` | 17,315,408.95 |
| Low case ($) | `=Ceiling * rate_low` | 4,328,852.24 |
| Base case ($) | `=Ceiling * rate_base` | 8,657,704.47 |
| High case ($) | `=Ceiling * rate_high` | 12,986,556.71 |
| Reliability-adjusted base ($) | `=SUMIFS(tblPairs[gap_to_median], tblPairs[vendor_on_time_pct], "<"&reliable_cutoff) * rate_base` | 5,315,096.39 |
| Annualized base ($/yr) | `=Base / years_in_data` | about 4.33M |
| Ceiling as % of total spend | `=Ceiling / SUM(tblVendors[spend])` | 3.47% |

PivotTables (Insert > PivotTable from the table, new sheet area on `Summary`):
1. **Gap by vendor:** rows `Vendor_Name`, values Sum of `gap_to_median`, sorted descending; slicers on `Product_Category`.
2. **Quadrants:** from `tblVendors`, rows `price_band`, columns `delivery_band`, values Count of `Vendor_Name` and Sum of `spend`. This reproduces 06 Section 3: expect 5 vendors and about $89.77M in Above benchmark / Weak (<70%).
3. **Gap by category:** rows `Product_Category`, values Sum of `gap_to_median`, with a bar chart beside it.

One chart is enough; keep it simple and label the axes in dollars.

## 6. Checks sheet (reconciliation to SQL)

One row per check: **Check | SQL value (typed, with source) | Workbook value (formula) | Difference | Pass?** where Pass is `=ABS(difference) <= 1`.

| Check | SQL value | Source |
|---|---|---|
| Total vendor spend | 499,651,571.54 | 06 Section 0 |
| Vendor count | 41 | 06 Section 2 |
| Flagged pair count | 96 | 06 Section 1a |
| Gap ceiling | 17,315,408.95 | 06 Section 1a |
| Low / base / high | 4,328,852.24 / 8,657,704.47 / 12,986,556.71 | 06 Section 1a |
| Reliability-adjusted base | 5,315,096.39 | 06 Section 1d |
| Vendors above benchmark AND under 70% on-time | 5 | 06 Section 3b |
| Spend with those vendors | 89,768,065.99 | 06 Section 3b |

The workbook gap ceiling will differ from SQL by a few cents because each CSV row was rounded to cents; the $1 tolerance covers it. Anything larger is a real discrepancy to investigate.

## 7. Limitations to state on the README sheet

- Gap = dollars paid above the product-level median on vendor-product pairs priced more than 5% above it (10+ lines); it is a ceiling, not a saving.
- Recovery rates (25 / 50 / 75%) are assumptions.
- The median is a midpoint on products with 2 vendors (about 16% of the ceiling).
- Prices are not contract-, volume- or time-adjusted.
- Delivery risk is not valued in dollars (no delay-cost data).
- Vendor price levels reflect generator settings in the synthetic data.

## 8. Commit

Add to the repo: `excel/savings_opportunity_model.xlsx`, `excel/data/vendor_scorecard.csv`, `excel/data/flagged_pairs.csv`. Update the README tree and the "Reproducing the database" section with one line: "Run `06_opportunity_analysis.sql` and save the last two result grids as the CSVs in `excel/data/`." Add a DECISIONS entry noting that the CSVs are query outputs, which also resolves the parked `data/cleaned/` question for the Excel step.