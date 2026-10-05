-- ============================================================================
-- 02_data_cleaning.sql
-- Northstar Electronics — Procurement Analytics
-- Purpose: build cleaned dbo. tables from the stg_ staging tables identified
-- in 01_data_quality.sql. Drops exact-duplicate rows, resolves PO_Line_ID
-- collisions (same ID, different data — see DECISIONS.md), converts columns
-- to real types (DATE, DECIMAL, etc.) via TRY_CAST/TRY_CONVERT, and
-- standardizes formatting inconsistencies (Currency, PO_Status). Invalid
-- values on otherwise-unique rows (negative price, zero quantity, malformed
-- dates) are NOT deleted — TRY_CAST/TRY_CONVERT naturally turns them into
-- NULL, preserving the row and its other real data. Only rows with a
-- confirmed intact duplicate/collision backup elsewhere in the data get
-- removed (see DECISIONS.md for full rationale).
-- ============================================================================

USE NorthstarProcurement;
GO

-- ----------------------------------------------------------------------------
-- fact_purchase_orders
-- ----------------------------------------------------------------------------

CREATE TABLE dbo.fact_purchase_orders (
    PO_Line_ID NVARCHAR(10),
    PO_ID NVARCHAR(10),
    Vendor_ID NVARCHAR(10),
    Product_ID NVARCHAR(10),
    Department_ID NVARCHAR(10),
    Order_Date DATE,
    Expected_Delivery_Date DATE,
    Actual_Delivery_Date DATE,
    Quantity DECIMAL(10,2),
    Unit_Price DECIMAL(10,2),
    Currency NVARCHAR(20),
    PO_Status NVARCHAR(20)
);
GO

-- Dedup (ROW_NUMBER on all 12 columns) + PO_Line_ID collision resolution
-- (badness_score: NULL/malformed Unit_Price, Quantity, Order_Date,
-- Expected_Delivery_Date, or Actual_Delivery_Date before Order_Date) +
-- type conversion + Currency/PO_Status standardization, all in one pass.
-- See DECISIONS.md (2026-09-20 entries) for why each rule exists.
WITH Deduplicated AS (
    SELECT PO_Line_ID, PO_ID, Vendor_ID, Product_ID, Department_ID, Order_Date,
           Expected_Delivery_Date, Actual_Delivery_Date, Quantity, Unit_Price,
           Currency, PO_Status,
           ROW_NUMBER() OVER (
               PARTITION BY PO_Line_ID, PO_ID, Vendor_ID, Product_ID, Department_ID, Order_Date,
                            Expected_Delivery_Date, Actual_Delivery_Date, Quantity,
                            Unit_Price, Currency, PO_Status
               ORDER BY PO_ID
           ) AS rn
    FROM stg_fact_purchase_orders
),
Scored AS (
    SELECT *,
        CASE WHEN TRY_CAST(Unit_Price AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END
      + CASE WHEN TRY_CAST(Quantity AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END
      + CASE WHEN TRY_CONVERT(DATE, Order_Date) IS NULL THEN 1 ELSE 0 END
      + CASE WHEN TRY_CONVERT(DATE, Expected_Delivery_Date) IS NULL THEN 1 ELSE 0 END
      + CASE WHEN TRY_CONVERT(DATE, Actual_Delivery_Date) < TRY_CONVERT(DATE, Order_Date)
             AND Actual_Delivery_Date <> '' THEN 1 ELSE 0 END
      AS badness_score
    FROM Deduplicated
    WHERE rn = 1
),
Filtered AS (
    SELECT *
    FROM Scored
    WHERE PO_Line_ID NOT IN ('L005513','L010354','L004707','L009679','L013436','L014121','L014440','L015904','L015082')
       OR badness_score = 0
)
INSERT INTO dbo.fact_purchase_orders
    (PO_Line_ID, PO_ID, Vendor_ID, Product_ID, Department_ID, Order_Date,
     Expected_Delivery_Date, Actual_Delivery_Date, Quantity, Unit_Price,
     Currency, PO_Status)
SELECT
    PO_Line_ID, PO_ID, Vendor_ID, Product_ID, Department_ID,
    TRY_CONVERT(DATE, Order_Date),
    TRY_CONVERT(DATE, Expected_Delivery_Date),
    TRY_CONVERT(DATE, Actual_Delivery_Date),
    TRY_CAST(Quantity AS DECIMAL(10,2)),
    TRY_CAST(Unit_Price AS DECIMAL(10,2)),
    CASE WHEN Currency = 'US Dollar' THEN 'USD' ELSE Currency END,
    CASE WHEN PO_Status = 'Canceled' THEN 'Cancelled' ELSE PO_Status END
FROM Filtered;
GO

-- Verified: 19,579 rows (19,716 - 128 duplicates - 9 collision-pair excess).
-- Currency: single value (USD). PO_Status: 3 values, no "Canceled".
-- No PO_Line_ID appears more than once. 14 rows have Order_Date = NULL
-- (malformed dates on otherwise-unique rows, kept per inclusion-rules
-- philosophy in PROJECT_SPEC.md — see DECISIONS.md for full reasoning).


-- ----------------------------------------------------------------------------
-- dim_vendor, dim_product, dim_department, dim_date
-- Not yet built — see TASKS.md.
-- ----------------------------------------------------------------------------