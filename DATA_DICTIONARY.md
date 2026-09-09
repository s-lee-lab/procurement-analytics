# DATA_DICTIONARY

Star schema: `fact_purchase_orders` at the center, joined to `dim_vendor`,
`dim_product`, `dim_department` (all 1→*), and `dim_date` (1→*, on Order_Date).

## fact_purchase_orders
Grain: **one row = one product line on a purchase order** (a PO can have multiple lines).

| Column | Type | Notes |
|---|---|---|
| PO_Line_ID | text | Unique per line (not guaranteed unique in raw data — ~0.7% intentional duplicate rows) |
| PO_ID | text | Groups lines belonging to the same purchase order |
| Vendor_ID | text | FK → dim_vendor |
| Product_ID | text | FK → dim_product |
| Department_ID | text | FK → dim_department |
| Order_Date | date | Small number of intentionally malformed values in raw data |
| Expected_Delivery_Date | date | Order_Date + lead time; ~0.5% intentionally missing in raw data |
| Actual_Delivery_Date | date | Blank for Open/Cancelled orders (expected, not an error); populated for Completed orders |
| Quantity | numeric | Range depends on product; ~0.4% intentionally missing/invalid (0 or negative) in raw data |
| Unit_Price | numeric | Influenced by product baseline, vendor pricing tendency, volume, year, noise; ~0.5% intentionally missing/invalid (negative) in raw data |
| Currency | text | "USD" with ~1.5% intentional formatting variants (usd, Usd, "US Dollar", " USD") |
| PO_Status | text | Completed / Open / Cancelled, with intentional casing variants |

**Calculated fields (built downstream in SQL/BI, not stored raw):**
- Total Line Cost = Quantity × Unit_Price
- Delivery Days Late = Actual_Delivery_Date − Expected_Delivery_Date (Completed only)
- On-Time Flag = Actual_Delivery_Date ≤ Expected_Delivery_Date (Completed, valid dates only)

## dim_vendor (~40 rows)
| Column | Notes |
|---|---|
| Vendor_ID | PK |
| Vendor_Name | |
| Vendor_Category | Vendor's primary category (IT Equipment, Software, Office Supplies, Facilities, Manufacturing, Professional Services, Logistics) |
| Region | Northeast US / Southeast US / Midwest US / West US / Southwest US / International |
| Vendor_Start_Date | Predates the PO data window |
| Vendor_Status | Active / Inactive (~5% Inactive) |

## dim_product (~110 rows)
| Column | Notes |
|---|---|
| Product_ID | PK |
| Product_Name | |
| Product_Category | See list above |
| Subcategory | e.g. Laptops, Toner, HVAC Maintenance, Components, Consulting, Freight |
| Standard_Cost | Baseline unit cost used as the pricing benchmark input |
| Unit_of_Measure | Each / License / Case / Box / Service / Hour / Session / Shipment / Month |

## dim_department (9 rows, fixed)
| ID | Department | Group |
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

## dim_date (Jan 1, 2024 – Dec 31, 2025, one row per day)
Date, Year, Quarter, Month, Month Name, Year-Month, Week, Day Name.

## Assumptions worth remembering during SQL/BI work
- Missing `Actual_Delivery_Date` is only a real "missing value" problem for
  Completed orders — it's expected and correct for Open/Cancelled orders.
- `PO_Status` and `Currency` need casing normalization before grouping/filtering.
- A handful of rows have `Order_Date` outside any valid calendar date
  (intentional malformed-date injection) — these should fail a join to
  `dim_date` and can be caught that way in `01_data_quality.sql`.
