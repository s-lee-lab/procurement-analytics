-- ============================================================================
-- 01_data_quality.sql
-- Northstar Electronics — Procurement Analytics
-- Purpose: identify (not yet fix) the controlled data-quality issues in the
-- raw staging tables, and confirm the rates match what was targeted/found
-- during the Python generation & inspection phase (see documentation/methodology.md).
-- ============================================================================

USE NorthstarProcurement;
GO

-- ----------------------------------------------------------------------------
-- 1. Duplicate rows
-- A duplicate = every column matches another row exactly.
-- Expected: ~125-135 duplicate groups (target was 0.5-1% of ~19,700 rows).
-- ----------------------------------------------------------------------------
SELECT PO_Line_ID, PO_ID, Vendor_ID, Product_ID, Department_ID, Order_Date,
       Expected_Delivery_Date, Actual_Delivery_Date, Quantity, Unit_Price, Currency, PO_Status
FROM stg_fact_purchase_orders
GROUP BY PO_Line_ID, PO_ID, Vendor_ID, Product_ID, Department_ID, Order_Date,
         Expected_Delivery_Date, Actual_Delivery_Date, Quantity, Unit_Price, Currency, PO_Status
HAVING COUNT(*) > 1;
-- Result: 128 duplicate groups. Matches target.


-- ----------------------------------------------------------------------------
-- 2. Missing values
-- Checking both NULL and empty string ('') since either can represent "blank"
-- depending on how the raw CSV cell came through the import.
-- Expected: each column individually lands around 90-105 rows
-- (target was ~1-2% combined across these 3 fields).
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS missing_unit_price
FROM stg_fact_purchase_orders
WHERE Unit_Price IS NULL OR Unit_Price = '';
-- Result: 100

SELECT COUNT(*) AS missing_quantity
FROM stg_fact_purchase_orders
WHERE Quantity IS NULL OR Quantity = '';
-- Result: 103

SELECT COUNT(*) AS missing_expected_delivery_date
FROM stg_fact_purchase_orders
WHERE Expected_Delivery_Date IS NULL OR Expected_Delivery_Date = '';
-- Result: 90


-- ----------------------------------------------------------------------------
-- 3. Invalid values (negative price, zero/negative quantity)
-- Columns are still text (nvarchar) at the staging layer, so TRY_CAST is used
-- to safely attempt a numeric conversion — malformed/blank values become NULL
-- instead of erroring the whole query out.
-- Expected: each ~35-40 rows (target was <0.5% combined).
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS negative_unit_price
FROM stg_fact_purchase_orders
WHERE TRY_CAST(Unit_Price AS DECIMAL(10,2)) < 0;
-- Result: 38

SELECT COUNT(*) AS zero_or_negative_quantity
FROM stg_fact_purchase_orders
WHERE TRY_CAST(Quantity AS DECIMAL(10,2)) <= 0;
-- Result: 39


-- ----------------------------------------------------------------------------
-- 4. Formatting inconsistencies (Currency, PO_Status)
-- Note: SQL Server's default collation is case-INsensitive, so casing variants
-- like 'usd'/'Usd'/'USD' collapse into one group here — genuine spelling
-- differences (e.g. 'Canceled' vs 'Cancelled') still show up separately.
-- ----------------------------------------------------------------------------
SELECT Currency, COUNT(*) AS cnt
FROM stg_fact_purchase_orders
GROUP BY Currency
ORDER BY cnt DESC;
-- Result: USD (19,688), US Dollar (28)

SELECT PO_Status, COUNT(*) AS cnt
FROM stg_fact_purchase_orders
GROUP BY PO_Status
ORDER BY cnt DESC;
-- Result: Completed (17,866), Open (1,248), Cancelled (598), Canceled (4)


-- ----------------------------------------------------------------------------
-- 5. Invalid dates — NOT YET WRITTEN
-- TODO: malformed Order_Date values, and Actual_Delivery_Date before Order_Date.
-- ----------------------------------------------------------------------------