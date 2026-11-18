# DATA_DICTIONARY — Procurement Spend & Vendor Performance Analytics

## 1. Data Model Overview

The project uses a five-table star schema centered on `fact_purchase_orders`.

**Fact table:** `fact_purchase_orders`

**Dimension tables:**
- `dim_vendor`
- `dim_product`
- `dim_department`
- `dim_date`

Each dimension has a one-to-many relationship with the fact table.

| Dimension | Join key | Fact table relationship |
|---|---|---|
| dim_vendor | Vendor_ID | Vendor_ID |
| dim_product | Product_ID | Product_ID |
| dim_department | Department_ID | Department_ID |
| dim_date | Date | Order_Date |

The `dim_date` relationship is based on `Order_Date` only. It does not provide complete coverage for delivery-date analysis because actual deliveries extend beyond the calendar table's end date.

The dimension tables were independently validated before loading. No duplicate dimension keys, missing required fields, failed date conversions, or orphan fact-table keys were found.

### Verified cleaned-table row counts

| Table | Rows |
|---|---:|
| fact_purchase_orders | 19,579 |
| dim_vendor | 41 |
| dim_product | 107 |
| dim_department | 9 |
| dim_date | 731 |

The raw fact table contained 19,716 rows. Cleaning removed 128 exact duplicate rows and 9 excess rows associated with reused PO_Line_ID values.

## 2. fact_purchase_orders

**Grain:** One row represents one product line on a purchase order. A single `PO_ID` may contain multiple lines.

The cleaned table preserves the PO-line grain. It contains the original purchasing attributes with standardized data types and corrected duplicate records.

| Column | SQL type | Description |
|---|---|---|
| PO_Line_ID | NVARCHAR(10) | Unique identifier for a purchase-order line after cleaning |
| PO_ID | NVARCHAR(10) | Purchase-order identifier shared by lines belonging to the same PO |
| Vendor_ID | NVARCHAR(10) | Foreign key to dim_vendor |
| Product_ID | NVARCHAR(10) | Foreign key to dim_product |
| Department_ID | NVARCHAR(10) | Foreign key to dim_department |
| Order_Date | DATE | Date the purchase order was placed |
| Expected_Delivery_Date | DATE | Expected delivery date based on order date and generated lead time |
| Actual_Delivery_Date | DATE | Actual delivery date; normally NULL for Open and Cancelled orders |
| Quantity | DECIMAL(10,2) | Quantity purchased on the PO line |
| Unit_Price | DECIMAL(10,2) | Observed unit purchase price |
| Currency | NVARCHAR(20) | Standardized currency; cleaned dataset uses USD |
| PO_Status | NVARCHAR(20) | Standardized purchasing status: Completed, Open, or Cancelled |

### Raw-data quality issues

The original fact data intentionally includes controlled data-quality problems.

| Issue | Approximate occurrence | Treatment |
|---|---:|---|
| Exact duplicate rows | 128 rows | Removed during cleaning |
| Reused PO_Line_ID values | 9 ID collisions | Resolved by retaining the more complete record |
| Missing or malformed dates | Small number of records | Converted to NULL where conversion fails; rows retained unless resolved as duplicate/collision records |
| Missing or invalid Quantity | Approximately 0.4% | Retained in the cleaned table; excluded from spend calculations |
| Missing or invalid Unit_Price | Approximately 0.5% | Retained in the cleaned table; excluded from spend calculations |
| Currency formatting variants | Approximately 1.5% | Standardized during cleaning |
| PO_Status formatting variants | Controlled variations | Standardized during cleaning |

**Important distinction:** The 128 exact duplicate rows and 9 reused PO_Line_ID cases are different problems. The former are repeated records; the latter involve identifiers appearing against conflicting or incomplete data.

For the nine identifier collisions, the cleaning process evaluates record completeness and retains the more complete record. This is documented in `DECISIONS.md`.

Malformed text values that fail conversion become NULL. Negative and zero numeric values remain in the cleaned table and are excluded explicitly by applicable analytical queries.

The cleaned table contains 19,579 records, with no remaining duplicate PO_Line_ID values.

### Calculated fields

The following metrics are calculated downstream in SQL or Power BI rather than stored as original fact-table columns.

| Calculated field | Definition | Purpose |
|---|---|---|
| Total Line Cost | Quantity × Unit_Price | Financial value of an individual PO line |
| Delivery Days Late | Actual_Delivery_Date − Expected_Delivery_Date | Measures delivery delay in calendar days |
| On-Time Flag | Actual_Delivery_Date ≤ Expected_Delivery_Date | Identifies on-time or early deliveries |
| Price Index | Unit_Price ÷ Product Median Unit Price | Compares observed price against the product benchmark |
| Purchase Price Variance (PPV) | (Unit_Price − Product Median Unit Price) × Quantity | Measures the dollar difference against the benchmark |
| Eligible Spend Flag | Completed status AND Quantity > 0 AND Unit_Price > 0 | Identifies records eligible for spend calculations |
| Valid Delivery Flag | Completed status, valid expected and actual dates, and no delivery before order date | Identifies records eligible for delivery KPIs |

**Sign convention:**
- Positive PPV = observed price above the product median (unfavorable price difference).
- Negative PPV = observed price below the product median (favorable price difference).
- Zero PPV = observed price equal to the product median.

PPV is a relative price comparison, not proof of overpayment.

## 3. dim_vendor

**Verified row count:** 41

| Column | SQL type | Description |
|---|---|---|
| Vendor_ID | NVARCHAR(10) | Primary key |
| Vendor_Name | NVARCHAR(100) | Vendor's business name |
| Vendor_Category | NVARCHAR(50) | Vendor's primary procurement category |
| Region | NVARCHAR(50) | Vendor's geographic region |
| Vendor_Start_Date | DATE | Date the vendor relationship began; predates the PO data window |
| Vendor_Status | NVARCHAR(20) | Vendor status: Active or Inactive |

### Vendor categories

- IT Equipment
- Software
- Office Supplies
- Facilities
- Manufacturing
- Professional Services
- Logistics

### Important analytical note

All 41 vendors are marked Active in the cleaned dataset.

Therefore, `Vendor_Status` does not distinguish vendors for comparative performance analysis.

Vendor comparisons should instead be based on purchasing activity, delivery performance, pricing, and other observed metrics.

See `DECISIONS.md` (2026-10-19) for the dimension-table validation findings.

## 4. dim_product

**Verified row count:** 107

| Column | SQL type | Description |
|---|---|---|
| Product_ID | NVARCHAR(10) | Primary key |
| Product_Name | NVARCHAR(100) | Product or service name |
| Product_Category | NVARCHAR(50) | Primary purchasing category |
| Subcategory | NVARCHAR(50) | More specific product or service classification |
| Standard_Cost | DECIMAL(10,2) | Generator-provided baseline unit cost |
| Unit_of_Measure | NVARCHAR(20) | Unit used to describe the purchased item or service |

### Example subcategories

- Laptops
- Toner
- HVAC Maintenance
- Components
- Consulting
- Freight

### Unit of measure

- Each
- License
- Case
- Box
- Service
- Hour
- Session
- Shipment
- Month

### Pricing methodology

`Standard_Cost` is a generated baseline cost and is retained as a secondary pricing reference.

It is **not the primary benchmark** used in the project's price variance analysis.

The primary benchmark is the observed product-level median unit price calculated from valid Completed PO lines across all vendors and both years.

The benchmark is calculated using:

`PERCENTILE_CONT(0.5)`

Partitioned by `Product_ID`.

The resulting comparison measures how individual observed prices differ from the median for the same product.

This approach is intended to identify relative pricing differences without assuming that the generated standard cost represents a negotiated market price.

## 5. dim_department

**Verified row count:** 9

This dimension is fixed and represents the company's organizational structure.

| Department_ID | Department | Group |
|---|---|---|
| D01 | IT | Technology |
| D02 | Operations | Operations |
| D03 | Finance | Corporate |
| D04 | Human Resources | Corporate |
| D05 | Facilities | Operations |
| D06 | Sales | Revenue |
| D07 | Marketing | Revenue |
| D08 | Engineering | Product |
| D09 | Manufacturing | Production |

The department dimension supports purchasing analysis by organizational function and business group.

## 6. dim_date

**Verified row count:** 731

**Date coverage:** January 1, 2024 – December 31, 2025.

One record exists for each calendar day.

| Column | Description |
|---|---|
| Date | Calendar date; primary key |
| Year | Calendar year |
| Quarter | Calendar quarter |
| Month | Numeric month |
| Month Name | Full month name |
| Year-Month | Combined year and month label |
| Week | Generated seven-day block number |
| Day Name | Day of the week |

### Date relationship and coverage limitation

`dim_date` is related to `fact_purchase_orders` through `Order_Date`.

This relationship supports order-date analysis, including monthly and annual purchasing trends.

However, actual delivery dates extend through April 19, 2026, beyond the calendar table's December 31, 2025 endpoint.

An earlier attempt to join delivery dates to `dim_date` dropped 158 otherwise valid delivery records.

**Current SQL approach:** Delivery reporting derives delivery periods directly from `Actual_Delivery_Date` instead of joining delivery dates to the existing date dimension.

This preserves all 17,648 eligible delivery lines.

If delivery-date reporting is later implemented in Power BI, the model must use an appropriately extended date table and a separate delivery-date relationship or another explicitly defined date-role approach.

### Week-number limitation

The `Week` column represents generated seven-day blocks beginning January 1. It should not automatically be treated as an ISO week number for formal week-over-week reporting.

See `DECISIONS.md` (2026-10-19 and 2026-11-02) for date-table validation and the delivery-date coverage issue.

## 7. Analytical Inclusion Rules

The same fact table supports different analytical populations. A record eligible for one KPI is not necessarily eligible for another.

### Spend analysis

Include:
- PO_Status = Completed
- Quantity > 0
- Unit_Price > 0

Calculation:

`Total Procurement Spend = SUM(Quantity × Unit_Price)`

The cleaned dataset contains 17,739 Completed PO lines. The validity conditions exclude approximately 239 lines (1.3%) from financial calculations.

These invalid numeric records remain in the fact table for transparency and data-quality reporting.

### PO count

`PO Count = COUNT(DISTINCT PO_ID)`

Calculated among eligible Completed purchasing activity.

This is a distinct purchase-order metric, not a count of fact-table rows.

### Active vendors

`Active Vendors = COUNT(DISTINCT Vendor_ID)`

Calculated among eligible Completed purchasing activity.

This is an analytical definition based on purchasing activity and should not be confused with the `Vendor_Status` field.

### Delivery analysis

Include:
- PO_Status = Completed
- Expected_Delivery_Date IS NOT NULL
- Actual_Delivery_Date IS NOT NULL
- Actual_Delivery_Date >= Order_Date

The latest validation identified:
- 17,739 Completed lines.
- 79 lines missing an Expected_Delivery_Date.
- 12 lines with delivery dates before the order date.
- 17,648 eligible delivery lines.

These exclusions are applied in analytical queries rather than deleting otherwise valid purchasing records.

**On-Time Delivery %**

`On-Time Lines / Eligible Delivery Lines`

**Average Days Late**

`Average(Actual_Delivery_Date - Expected_Delivery_Date)`

Restricted to eligible lines where Actual_Delivery_Date is later than Expected_Delivery_Date.

### Time-based spend analysis

Spend trends use `Order_Date`.

Nine Completed lines with missing or invalid Order_Date cannot be assigned to a valid reporting period, but remain included in eligible overall spend totals if their quantity and unit price are valid.

This creates a small difference between overall spend and the sum of time-based spend.

## 8. Pricing and Opportunity Analysis Rules

The project uses two related but distinct analytical thresholds.

### Product-level pricing analysis

The primary price benchmark is calculated for each product using valid Completed lines with positive quantities and prices.

The SQL analysis evaluates benchmark coverage and product-level sample sizes. Products with fewer than 30 valid Completed lines are treated as too thin for the primary stable-median comparisons.

The main calculated metrics are:

- Product median unit price.
- Vendor price index.
- Purchase price variance.
- Price distribution and variation.
- Differences between observed median pricing and Standard_Cost.

The benchmark includes purchasing activity across both years and all vendors.

It is not adjusted for contract terms, order timing, shipping, service levels, or other commercial conditions.

### Vendor-product opportunity analysis

The opportunity analysis applies additional screening at the vendor-product pair level.

A pair must have:
- At least 10 purchase lines.
- A price index above 1.05.

The resulting positive PPV is aggregated to estimate the dollar gap above the product median.

The project uses the gap as a theoretical opportunity ceiling and applies 25%, 50%, and 75% recovery assumptions to create low, base, and high scenarios.

These recovery rates are scenario assumptions, not measured savings or supplier commitments.

Products with only two vendors require additional caution because the median is simply the midpoint between the two observed vendor prices.

## 9. Important Data Assumptions and Limitations

### Missing delivery dates

A missing `Actual_Delivery_Date` is expected for Open and Cancelled orders.

It is a data-quality issue for Completed orders, where an actual delivery should normally be recorded.

A missing `Expected_Delivery_Date` prevents the corresponding line from being evaluated for on-time delivery.

### Open and Cancelled orders

Open and Cancelled orders are excluded from Completed-only spend and delivered-line performance KPIs.

They remain in the dataset for separate operational analysis.

However, Open status is assigned by the synthetic generator primarily according to order recency. It does not establish an actual supplier backlog or demonstrate vendor-caused delays.

Open-order aging is therefore illustrative and must be labeled with its reference date.

### Supplier performance

On-time delivery measures delivery timeliness, not complete fulfillment.

The dataset does not contain a received-quantity field, so on-time-in-full (OTIF) cannot be calculated.

The dataset also lacks a cost-of-delay field, so delivery problems cannot be translated into a defensible financial impact.

### Pricing

Observed pricing differences are investigation candidates, not confirmed overpayment.

They may reflect differences in:
- Contract terms.
- Negotiated pricing.
- Product specifications.
- Order quantities.
- Service levels.
- Shipping.
- Purchasing timing.

The median benchmark is a relative comparison, not a verified market price.

### Synthetic data

All records are generated for portfolio and analytical demonstration.

The number of vendors, products, spend distribution, category mix, pricing patterns, and purchasing behavior are generator settings.

Results should not be interpreted as real procurement benchmarks.

## 10. Related Documentation

| Document | Purpose |
|---|---|
| `README.md` | Project overview, findings, technical approach, and limitations |
| `PROJECT_SPEC.md` | Business problem, scope, stakeholders, KPI requirements, and methodology |
| `DECISIONS.md` | Analytical decisions, data-quality corrections, and methodology changes |
| `TASKS.md` | Current progress and outstanding deliverables |
| `documentation/methodology.md` | Raw-data validation and inspection report |
| `sql/01_data_quality.sql` | Raw staging-table quality audit |
| `sql/02_data_cleaning.sql` | Cleaning and dimensional-model construction |
| `sql/03_spend_analysis.sql` | Spend KPIs and purchasing trends |
| `sql/04_vendor_performance.sql` | Vendor concentration and delivery performance |
| `sql/05_pricing_analysis.sql` | Product-level pricing analysis and PPV |
| `sql/06_opportunity_analysis.sql` | Savings opportunity sizing and vendor scorecard |
| `sql/07_spend_forecast.sql` | Monthly ordered-spend forecast and backtesting |

**Documentation standard:** Table definitions, calculated metrics, inclusion rules, and analytical assumptions should remain consistent across the data dictionary, project specification, SQL scripts, and Power BI model. Any methodology change should be recorded in `DECISIONS.md` and reflected in affected documentation.