-- ============================================================================
-- 01_data_quality.sql
-- Northstar Electronics — Procurement Analytics
-- Auditing the raw staging tables before touching anything. This just finds
-- and counts the issues — nothing gets fixed here, that's 02_data_cleaning.sql.
-- Numbers below should line up with what the Python inspection already found
-- (see documentation/methodology.md).
-- ============================================================================

USE NorthstarProcurement;
GO

-- ----------------------------------------------------------------------------
-- 1. Duplicate rows
-- Duplicate = every column matches another row exactly.
-- Target was 0.5-1% of ~19,700 rows, so expecting ~125-135 groups.
-- ----------------------------------------------------------------------------
SELECT PO_Line_ID, PO_ID, Vendor_ID, Product_ID, Department_ID, Order_Date,
       Expected_Delivery_Date, Actual_Delivery_Date, Quantity, Unit_Price, Currency, PO_Status
FROM stg_fact_purchase_orders
GROUP BY PO_Line_ID, PO_ID, Vendor_ID, Product_ID, Department_ID, Order_Date,
         Expected_Delivery_Date, Actual_Delivery_Date, Quantity, Unit_Price, Currency, PO_Status
HAVING COUNT(*) > 1;
-- 128 groups. On target.


-- ----------------------------------------------------------------------------
-- 2. Missing values
-- Checking NULL and '' separately since a blank CSV cell can come through as
-- either one depending on how the import handled it.
-- Expecting each column somewhere around 90-105 rows.
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS missing_unit_price
FROM stg_fact_purchase_orders
WHERE Unit_Price IS NULL OR Unit_Price = '';
-- 100

SELECT COUNT(*) AS missing_quantity
FROM stg_fact_purchase_orders
WHERE Quantity IS NULL OR Quantity = '';
-- 103

SELECT COUNT(*) AS missing_expected_delivery_date
FROM stg_fact_purchase_orders
WHERE Expected_Delivery_Date IS NULL OR Expected_Delivery_Date = '';
-- 90


-- ----------------------------------------------------------------------------
-- 3. Invalid values (negative price, zero/negative quantity)
-- Everything's still nvarchar at this stage, so TRY_CAST handles the numeric
-- conversion safely — bad/blank values just come back NULL instead of
-- blowing up the query.
-- Expecting ~35-40 rows each.
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS negative_unit_price
FROM stg_fact_purchase_orders
WHERE TRY_CAST(Unit_Price AS DECIMAL(10,2)) < 0;
-- 38

SELECT COUNT(*) AS zero_or_negative_quantity
FROM stg_fact_purchase_orders
WHERE TRY_CAST(Quantity AS DECIMAL(10,2)) <= 0;
-- 39


-- ----------------------------------------------------------------------------
-- 4. Formatting inconsistencies (Currency, PO_Status)
-- SQL Server's default collation is case-insensitive, so casing differences
-- like 'usd' vs 'USD' already collapse together here on their own. Real
-- spelling differences like 'Canceled' vs 'Cancelled' still show up as
-- separate groups, which is what we want to catch.
-- ----------------------------------------------------------------------------
SELECT Currency, COUNT(*) AS cnt
FROM stg_fact_purchase_orders
GROUP BY Currency
ORDER BY cnt DESC;
-- USD: 19,688 / US Dollar: 28

SELECT PO_Status, COUNT(*) AS cnt
FROM stg_fact_purchase_orders
GROUP BY PO_Status
ORDER BY cnt DESC;
-- Completed: 17,866 / Open: 1,248 / Cancelled: 598 / Canceled: 4


-- ----------------------------------------------------------------------------
-- 5. Invalid dates
-- TRY_CONVERT returns NULL for text that can't parse as a real date at all
-- (e.g. "2024-13-45"). Blank dates are excluded here on purpose — that's a
-- missing-value issue, already counted above, not a malformed-text issue.
-- Two different bugs, so they need to stay separate.
-- Expecting ~13-16 malformed Order_Date rows.
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS malformed_order_date
FROM stg_fact_purchase_orders
WHERE TRY_CONVERT(DATE, Order_Date) IS NULL AND Order_Date <> '';
-- 16, all the same bad value: "2024-13-45"

-- A delivery can't happen before the order was placed, so any row where
-- that's true is a real error. Blank Actual_Delivery_Date is excluded since
-- that's just the normal state for Open/Cancelled orders (see
-- DATA_DICTIONARY.md), not a mistake.
-- Expecting ~13 rows.
SELECT COUNT(*) AS delivery_before_order
FROM stg_fact_purchase_orders
WHERE TRY_CONVERT(DATE, Actual_Delivery_Date) < TRY_CONVERT(DATE, Order_Date)
  AND Actual_Delivery_Date <> '';
-- 13


-- ----------------------------------------------------------------------------
-- 6. PO_Line_ID collisions (same ID, different data underneath)
-- This is different from the duplicate check up top. That one catches rows
-- that are copies of each other. This catches the opposite problem: the same
-- PO_Line_ID showing up on two rows that AREN'T copies — meaning the ID got
-- reused by mistake. Gluing every non-ID column into one string with CONCAT
-- makes it easy to check whether both rows under an ID are really identical
-- or not.
-- ----------------------------------------------------------------------------
SELECT PO_Line_ID, COUNT(*) AS row_count,
       COUNT(DISTINCT CONCAT(PO_ID, '|', Vendor_ID, '|', Product_ID, '|', Department_ID, '|', Order_Date, '|', Expected_Delivery_Date, '|', Actual_Delivery_Date, '|', Quantity, '|', Unit_Price, '|', Currency, '|', PO_Status)) AS distinct_versions
FROM stg_fact_purchase_orders
GROUP BY PO_Line_ID
HAVING COUNT(DISTINCT CONCAT(PO_ID, '|', Vendor_ID, '|', Product_ID, '|', Department_ID, '|', Order_Date, '|', Expected_Delivery_Date, '|', Actual_Delivery_Date, '|', Quantity, '|', Unit_Price, '|', Currency, '|', PO_Status)) > 1
ORDER BY distinct_versions DESC;
-- 9 collisions found. 8 are near-duplicates where one copy is just missing/
-- malformed one field (see DECISIONS.md). 1 (L014440) is a real conflict
-- between two valid-looking values with no way to tell which is correct.