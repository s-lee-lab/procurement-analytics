# PROJECT_SPEC — Procurement Spend & Vendor Performance Analytics

## 1. Career Objective

This portfolio project supports a transition from operations and general affairs into Data Analyst, BI Analyst, Business Analyst, and Operations/Procurement Analyst roles.

The goal is to demonstrate the ability to take a business problem from initial requirements through data preparation, analysis, and decision support:

**Business understanding → Data quality → Data preparation → SQL analysis → BI modeling → Decision support → Recommendations**

The project prioritizes practical business understanding, analytical judgment, and clear communication over technical complexity for its own sake. Every metric, assumption, and recommendation should be explainable and defensible in an interview.

## 2. Company Background (Fictional)

**Northstar Electronics** is a fictional U.S.-based electronics and technology manufacturer with approximately 1,000 employees, multiple U.S. offices, and both manufacturing/assembly operations and corporate functions.

The company purchases production materials and components in addition to software, IT equipment, facilities services, office supplies, and professional services.

Annual procurement spend is approximately $250M. This scale is intentional: manufacturing and assembly purchases account for a substantial portion of spending, making the figure more appropriate than a general administrative purchasing budget alone.

All company information and purchasing records are synthetically generated. The project is not based on, and must never be represented as based on, any real company's internal data.

## 3. Business Problem

Procurement leadership has visibility into purchasing activity but lacks a consolidated view of supplier performance, spending patterns, pricing differences, supplier concentration, and delivery reliability.

Without a consistent analytical view, it is difficult to identify where procurement should focus its attention, which suppliers may warrant further review, and where cost or operational improvements may be possible.

The objective is to turn purchasing data into actionable information that supports procurement and operational decisions.

Findings should identify **investigation candidates, not proven verdicts**. A pricing difference or poor delivery result does not automatically establish supplier underperformance or achievable savings.

## 4. Stakeholders

| Stakeholder | Primary concerns |
|---|---|
| Procurement Manager | Supplier performance, pricing, concentration, negotiation opportunities |
| Finance Manager | Total spend, spending trends, cost control, financial exposure |
| Operations Manager | Delivery reliability, delays, supplier-related operational issues |
| Procurement Analyst | Vendor comparisons, purchasing patterns, price variation, reporting |

The primary audience is the Procurement Manager, with supporting information designed to help Finance and Operations evaluate the findings.

## 5. Core Business Questions

1. How much is the company spending, and how has spending changed over time?
2. Which departments, categories, and subcategories account for the largest share of spend?
3. Which vendors account for the most purchasing activity, and how concentrated is supplier spend?
4. Which vendors demonstrate the strongest and weakest delivery performance?
5. Which products have meaningful price variation across vendors?
6. Is observed price variation associated with purchasing volume or changes over time?
7. Where are delivery delays concentrated by vendor, department, and product category?
8. Which vendors or vendor-product combinations warrant further procurement investigation?
9. What potential savings opportunities can be quantified using transparent assumptions?
10. What does historical purchasing activity suggest about near-term spending, and how reliable is that estimate?

## 6. Project Scope and Technology

### Core workflow

**Excel / Power Query → SQL → Power BI**

Supporting technology:
- **Python:** Synthetic data generation and controlled data-quality injection.
- **Excel / Power Query:** Planned savings opportunity model, scenario analysis, and tracking.
- **SQL Server:** Data validation, cleaning, relational modeling, KPI calculations, and analytical queries.
- **Power BI:** Planned semantic model, DAX measures, interactive reporting, and stakeholder-facing dashboards.

Python supports the creation of the dataset but is not the centerpiece of the portfolio. The primary focus is using data to solve a procurement business problem.

### Current implementation status

| Component | Status |
|---|---|
| Business requirements and KPI definitions | Complete |
| Synthetic data generation | Complete |
| Raw-data inspection and validation | Complete |
| SQL staging, cleaning, and dimensional modeling | Complete |
| SQL spend and vendor performance analysis | Complete |
| SQL pricing and opportunity analysis | Complete |
| SQL spending forecast and backtesting | Complete |
| Excel savings opportunity model | Planned |
| Power BI semantic model and dashboard | Planned |
| UAT and reconciliation | Planned |
| Executive brief | Planned |

Status should be updated as deliverables are completed. Do not describe planned functionality as implemented.

## 7. Data Architecture and Fact Table Grain

The project uses a five-table dimensional model.

**Fact table:** `fact_purchase_orders`

**Dimension tables:**
- `dim_vendor`
- `dim_product`
- `dim_department`
- `dim_date`

The fact table grain is **one row per purchase-order line item**.

A single purchase order (`PO_ID`) may contain multiple product lines. This distinction matters because individual lines belonging to the same PO can have different quantities, prices, and delivery outcomes.

For example, one PO may contain two lines delivered on time and another delivered late. Therefore, delivery performance is measured at the PO-line level rather than treating an entire purchase order as either on time or late.

The dimensional model and all downstream calculations must preserve this grain unless a specific analysis explicitly requires aggregation to another level.

## 8. KPI Definitions

Detailed column definitions and calculated-field logic are maintained in `DATA_DICTIONARY.md`.

| KPI | Definition |
|---|---|
| Total Procurement Spend | Sum of Quantity × Unit_Price for eligible Completed PO lines |
| PO Count | COUNT(DISTINCT PO_ID) among eligible Completed purchasing activity |
| Active Vendors | Distinct vendors with eligible Completed purchasing activity |
| Average PO Value | Total eligible Completed spend ÷ distinct Completed PO count |
| On-Time Delivery % | Eligible Completed PO lines delivered on or before the expected date ÷ eligible Completed PO lines with valid expected and actual dates |
| Average Days Late | Average positive difference between actual and expected delivery dates among late Completed PO lines with valid dates |
| Vendor Spend Share | Vendor's eligible Completed spend ÷ total eligible Completed spend |
| Price Variance | Observed unit price compared with the product-level median benchmark |
| Price Index | Vendor-product observed unit price ÷ product-level median unit price |

### KPI calculation principles

- Spend and financial KPIs use Completed PO lines only.
- PO Count is a distinct PO-level metric; delivery KPIs remain at PO-line grain.
- Delivery metrics exclude lines without valid expected and actual delivery dates.
- Average Days Late includes late lines only, not early or on-time deliveries.
- Price comparisons use a product-level median benchmark calculated across both years and all vendors.
- Standard_Cost is retained as a secondary pricing reference, not the primary benchmark.

### Price benchmark methodology

The primary benchmark is the **median observed unit price for each product across both years and all vendors**.

The median is preferred over the mean because it is less sensitive to unusually high or low observations.

For each vendor-product combination:

`Price Index = Vendor's Observed Unit Price / Product Median Unit Price`

A price index above 1.00 indicates pricing above the product median; below 1.00 indicates pricing below it.

The benchmark is intended to support relative comparisons, not establish a definitive fair market price.

Products with only two vendors require additional caution because their median is simply the midpoint between the two observations. These comparisons should be distinguished from products with three or more vendors.

## 9. Inclusion and Exclusion Rules

### Spend analysis

Include:
- PO lines with `PO_Status = Completed`.
- Lines with valid, positive Quantity.
- Lines with valid, positive Unit_Price.

Exclude from spend calculations:
- Open and Cancelled PO lines.
- Completed lines with missing, zero, or negative Quantity.
- Completed lines with missing, zero, or negative Unit_Price.

Approximately 1.3% of Completed lines contain invalid or missing quantity/price values. These records remain available in the cleaned fact table, but are excluded explicitly from applicable financial calculations.

### Time-based spend analysis

- Spend trends are dated using `Order_Date`.
- Completed lines with invalid or missing Order_Date remain included in eligible overall spend totals but cannot be assigned to a valid time period.
- Nine Completed lines (approximately 0.03% of spend) lack a valid Order_Date.

### Delivery analysis

Include:
- Completed PO lines.
- Valid `Expected_Delivery_Date`.
- Valid `Actual_Delivery_Date`.

Open and Cancelled orders are excluded from delivered-line performance metrics.

This creates an important survivorship limitation: orders that remain Open, including potentially overdue orders, do not count as late in the delivered-line on-time calculation.

### Open-order analysis

Open and Cancelled orders are retained for separate operational analysis.

However, Open status is a synthetic generator assignment based primarily on order recency, not a representation of actual supplier backlog or vendor behavior.

Open-order aging must therefore be presented as an illustrative analytical exercise rather than a confirmed operational finding.

## 10. Data Quality and Analytical Philosophy

The project distinguishes between data-quality errors and business anomalies.

**Data-quality errors** are issues that undermine the reliability or consistency of the data and may require cleaning.

Examples:
- Duplicate records.
- Reused PO line identifiers.
- Missing keys.
- Invalid or impossible dates.
- Missing, zero, or negative quantities and prices.
- Inconsistent capitalization or formatting.

**Business anomalies** are unusual patterns that may represent legitimate business activity and should not automatically be removed.

Examples:
- Vendors consistently charging more for comparable products.
- Unusually late deliveries.
- Large purchasing transactions.
- Differences in vendor pricing.
- High supplier concentration.

The guiding principle is to correct data integrity problems without removing potentially meaningful business information.

The generator should create realistic conditions and controlled data-quality issues. Analytical findings should emerge from inspection and validation rather than being predetermined and forced into the results.

## 11. Forecasting Methodology

The project includes a short-term spending forecast based on historical monthly ordered spend.

The selected method is a six-month moving average (`MA6`), evaluated against alternative approaches using a two-origin backtest.

The forecast is intended to demonstrate the ability to compare simple forecasting methods, evaluate historical error, and communicate uncertainty.

It is not intended to represent a production forecasting system.

The forecast should:
- Display historical actuals and the projected period.
- Show a reasonable indication of forecast error.
- Explain that the selected method does not account for an underlying upward trend.
- Avoid implying that the projected figures are guaranteed purchasing commitments.

The forecast and its limitations are documented in `DECISIONS.md` and the README.

## 12. Reference Dates and Date Coverage

The synthetic purchasing dataset covers order activity from January 1, 2024 through December 31, 2025.

However, actual delivery dates extend through **April 19, 2026**.

The original `dim_date` table ends December 31, 2025, which means its coverage is insufficient for delivery-date reporting through the full dataset.

Delivery analysis must derive delivery periods directly from valid delivery dates or use an appropriately extended date table. A date relationship must not silently exclude valid delivery records.

For Open-order aging, use two reference dates:

- **December 31, 2025:** The original reference date used by the synthetic status generator.
- **April 19, 2026:** A sensitivity date reflecting the latest delivery-date coverage.

The distinction must be documented wherever Open-order aging is presented.

## 13. Known Limitations and Assumptions

The following limitations must be carried into the README, dashboard, executive brief, and relevant analytical documentation.

### Synthetic data

All purchasing records are generated.

The dataset does not represent actual supplier contracts, negotiated terms, purchasing policies, or real-world procurement behavior.

The scale of spend, category mix, vendor pricing patterns, and other distributions are generator settings. For example, Software accounts for approximately 27.9% of spend, an unusually high share for a company of this size.

These characteristics provide a useful analytical environment but should not be interpreted as industry benchmarks.

### Pricing and savings assumptions

A higher observed price does not automatically indicate overpayment.

Price differences may reflect:
- Contract terms and negotiated pricing.
- Product specifications and quality differences.
- Order size and purchasing conditions.
- Shipping and service levels.
- Timing and market conditions.

The price gap represents dollars paid above the selected product-level median benchmark. It is not confirmed overpayment or guaranteed savings.

Any savings scenarios must clearly identify their assumed recovery rates and distinguish theoretical opportunity from achievable financial results.

Two-vendor products require additional caution because the median is only the midpoint between two observations. Results for products with three or more vendors should be shown as a more conservative comparison.

### Delivery performance

Delivery KPIs cover Completed lines with valid delivery dates only.

Late orders that remain Open are excluded from delivered-line performance calculations. As a result, reported on-time performance may not fully capture supplier delivery risk.

The dataset also lacks a received-quantity field, so the project cannot calculate on-time-in-full (OTIF) performance.

There is no cost-of-delay field, so delivery risk cannot be converted into a defensible financial impact.

### Open-order status

Open status is assigned by the synthetic generator primarily based on order recency.

The overdue-Open-order report demonstrates an analytical approach but cannot establish actual supplier backlog or prove that a vendor is responsible for delayed orders.

Open-order aging must be labeled with its reference date and described as illustrative.

### End-of-data effect

The order dataset ends December 31, 2025.

Orders placed toward the end of the dataset are more likely to remain Open, which makes recent Completed-only spend appear artificially low.

This affects the interpretation of recent monthly trends and can understate year-over-year growth in Completed spend.

For trend reporting, ordered spend (Completed plus Open) is the preferred measure when the objective is to understand purchasing activity. Completed-only spend should be accompanied by an appropriate end-of-data explanation.

### Forecast limitations

The forecast is based on only 24 monthly observations.

The selected six-month moving average assumes no underlying trend, even though 2025 ordered spend was approximately 4.6% higher than 2024.

Its historical backtest is also limited, and the method selection occurred after reviewing the results, which introduces some selection bias.

The forecast should be presented as an exploratory estimate rather than a reliable long-term projection.

### Other scope limitations

The project does not currently support:
- Inventory or material requirements planning (MRP).
- Contract compliance analysis.
- Maverick-spend analysis.
- On-time-in-full measurement.
- Machine-learning forecasting.
- Cloud-based data engineering or enterprise-scale deployment.

These areas are outside the current scope because the necessary data or implementation requirements are not available.

## 14. Documentation and Source of Truth

The project maintains separate documentation for requirements, data definitions, analytical decisions, and execution status.

| Document | Purpose |
|---|---|
| `README.md` | Project overview, findings, technical approach, and portfolio presentation |
| `PROJECT_SPEC.md` | Business requirements, scope, KPI definitions, and limitations |
| `DATA_DICTIONARY.md` | Table structures, column definitions, relationships, and calculated fields |
| `DECISIONS.md` | Analytical decisions, bugs, corrections, assumptions, and methodology changes |
| `TASKS.md` | Completed work, current priorities, and planned deliverables |
| `documentation/methodology.md` | Detailed raw-data validation and inspection results |

When a methodology or KPI definition changes, all affected documentation and analytical deliverables should be reviewed for consistency.

The README should communicate the latest verified results. The decision log should preserve why those results and methodologies were chosen.

**Final standard:** Every reported metric should be traceable to its underlying calculation, every assumption should be disclosed, and every recommendation should be supported by evidence rather than presented as a predetermined conclusion.