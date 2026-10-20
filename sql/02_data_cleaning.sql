-- ============================================================================
-- 02_data_cleaning.sql
-- Northstar Electronics — Procurement Analytics
-- Purpose: build cleaned dbo. tables from the stg_ staging tables audited in
-- 01_data_quality.sql. Staging tables are never modified.
--
-- fact_purchase_orders: drops exact-duplicate rows, resolves PO_Line_ID
-- collisions (same ID, different data), converts columns to real types via
-- TRY_CAST/TRY_CONVERT, and standardizes Currency and PO_Status. Invalid
-- values on otherwise-unique rows (negative price, zero quantity, malformed
-- dates) are NOT deleted: they convert to NULL and the row stays. Only rows
-- with a confirmed intact duplicate/collision backup elsewhere in the data
-- get removed. See DECISIONS.md for full rationale.
--
-- dim_department / dim_vendor / dim_product / dim_date: audited clean, so
-- these only need trimming, real types, and primary keys.
--
-- Every table is dropped and rebuilt, so the whole script is safe to re-run.
-- ============================================================================

USE NorthstarProcurement;
GO

-- ----------------------------------------------------------------------------
-- fact_purchase_orders
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.fact_purchase_orders;
GO

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
-- philosophy in PROJECT_SPEC.md; see DECISIONS.md for full reasoning).


-- ----------------------------------------------------------------------------
-- dim_department
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.dim_department;
GO
CREATE TABLE dbo.dim_department (
    Department_ID NVARCHAR(10) NOT NULL PRIMARY KEY,
    Department NVARCHAR(50),
    [Group] NVARCHAR(50)
);
GO
INSERT INTO dbo.dim_department (Department_ID, Department, [Group])
SELECT LTRIM(RTRIM(Department_ID)), LTRIM(RTRIM(Department)), LTRIM(RTRIM([Group]))
FROM stg_dim_department;
GO
-- Verified: 9 rows.


-- ----------------------------------------------------------------------------
-- dim_vendor
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.dim_vendor;
GO
CREATE TABLE dbo.dim_vendor (
    Vendor_ID NVARCHAR(10) NOT NULL PRIMARY KEY,
    Vendor_Name NVARCHAR(100),
    Vendor_Category NVARCHAR(50),
    Region NVARCHAR(50),
    Vendor_Start_Date DATE,
    Vendor_Status NVARCHAR(20)
);
GO
INSERT INTO dbo.dim_vendor (Vendor_ID, Vendor_Name, Vendor_Category, Region, Vendor_Start_Date, Vendor_Status)
SELECT LTRIM(RTRIM(Vendor_ID)), LTRIM(RTRIM(Vendor_Name)), LTRIM(RTRIM(Vendor_Category)),
       LTRIM(RTRIM(Region)), TRY_CONVERT(DATE, Vendor_Start_Date), LTRIM(RTRIM(Vendor_Status))
FROM stg_dim_vendor;
GO
-- Verified: 41 rows, no NULLs from date conversion.


-- ----------------------------------------------------------------------------
-- dim_product
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.dim_product;
GO
CREATE TABLE dbo.dim_product (
    Product_ID NVARCHAR(10) NOT NULL PRIMARY KEY,
    Product_Name NVARCHAR(100),
    Product_Category NVARCHAR(50),
    Subcategory NVARCHAR(50),
    Standard_Cost DECIMAL(10,2),
    Unit_of_Measure NVARCHAR(20)
);
GO
INSERT INTO dbo.dim_product (Product_ID, Product_Name, Product_Category, Subcategory, Standard_Cost, Unit_of_Measure)
SELECT LTRIM(RTRIM(Product_ID)), LTRIM(RTRIM(Product_Name)), LTRIM(RTRIM(Product_Category)),
       LTRIM(RTRIM(Subcategory)), TRY_CAST(Standard_Cost AS DECIMAL(10,2)), LTRIM(RTRIM(Unit_of_Measure))
FROM stg_dim_product;
GO
-- Verified: 107 rows, no NULLs from cost conversion.


-- ----------------------------------------------------------------------------
-- dim_date
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.dim_date;
GO
CREATE TABLE dbo.dim_date (
    [Date] DATE NOT NULL PRIMARY KEY,
    [Year] INT,
    [Quarter] NVARCHAR(2),
    [Month] INT,
    Month_Name NVARCHAR(20),
    Year_Month NVARCHAR(7),
    [Week] INT,
    Day_Name NVARCHAR(20)
);
GO
INSERT INTO dbo.dim_date ([Date], [Year], [Quarter], [Month], Month_Name, Year_Month, [Week], Day_Name)
SELECT TRY_CONVERT(DATE, [Date]), TRY_CAST([Year] AS INT), LTRIM(RTRIM([Quarter])),
       TRY_CAST([Month] AS INT), LTRIM(RTRIM(Month_Name)), LTRIM(RTRIM(Year_Month)),
       TRY_CAST([Week] AS INT), LTRIM(RTRIM(Day_Name))
FROM stg_dim_date;
GO
-- Verified: 731 rows, 2024-01-01 to 2025-12-31, no NULL dates.
-- Note: Week appears to count simple 7-day blocks from Jan 1, not ISO weeks.