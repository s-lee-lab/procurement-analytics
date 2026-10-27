-- ============================================================================
-- 03_spend_analysis.sql
-- Northstar Electronics — Procurement Analytics
-- Purpose: first analysis script. Answers the spend questions from
-- PROJECT_SPEC.md: how much are we spending, how has it changed over time,
-- and which departments and categories drive it. Reads from the cleaned
-- dbo. tables built in 02_data_cleaning.sql. Nothing is modified here.
--
-- Inclusion rule used in every query below: PO_Status = 'Completed' AND
-- Quantity > 0 AND Unit_Price > 0. Negative/zero values are invalid, and
-- they were deliberately left in the cleaned table (see DECISIONS.md), so
-- each analysis excludes them explicitly. Spend is dated by Order_Date.
-- ============================================================================

USE NorthstarProcurement;
GO

-- ----------------------------------------------------------------------------
-- 0. Readiness check: how many Completed lines would the validity rule touch?
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*) AS completed_lines,
    SUM(CASE WHEN Quantity IS NULL OR Unit_Price IS NULL THEN 1 ELSE 0 END) AS missing_qty_or_price,
    SUM(CASE WHEN Quantity <= 0 THEN 1 ELSE 0 END) AS zero_or_negative_qty,
    SUM(CASE WHEN Unit_Price <= 0 THEN 1 ELSE 0 END) AS zero_or_negative_price,
    SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END) AS missing_order_date
FROM dbo.fact_purchase_orders
WHERE PO_Status = 'Completed';
-- Result: 17,739 Completed lines. 176 missing qty or price, 30 zero/negative
-- qty, 33 zero/negative price, 9 missing Order_Date. The validity rule
-- excludes at most 239 lines (~1.3%); a line can fall in more than one bucket.


-- ----------------------------------------------------------------------------
-- 1. Headline KPIs (PROJECT_SPEC.md definitions)
-- PO Count is distinct PO_ID, a PO-level metric. Spend is line-level.
-- ----------------------------------------------------------------------------
SELECT
    SUM(Quantity * Unit_Price)                          AS total_spend,
    COUNT(DISTINCT PO_ID)                               AS po_count,
    COUNT(DISTINCT Vendor_ID)                           AS active_vendors,
    SUM(Quantity * Unit_Price) / COUNT(DISTINCT PO_ID)  AS avg_po_value
FROM dbo.fact_purchase_orders
WHERE PO_Status = 'Completed' AND Quantity > 0 AND Unit_Price > 0;
-- Result: total spend $499,651,571.54 | 8,014 POs | 41 active vendors |
-- average PO value $62,347.34. Total is ~0.7% below the ~$503M generator
-- estimate, in the expected direction after removing duplicates and invalid lines.


-- ----------------------------------------------------------------------------
-- 2. Spend by year, with year-over-year change
-- First JOIN: fact to dim_date on the order date. LAG() looks at the previous
-- row in the ordering, which is how we get last year's spend next to this year's.
-- ----------------------------------------------------------------------------
WITH yearly AS (
    SELECT d.[Year] AS order_year,
           SUM(f.Quantity * f.Unit_Price) AS spend
    FROM dbo.fact_purchase_orders f
    JOIN dbo.dim_date d ON f.Order_Date = d.[Date]
    WHERE f.PO_Status = 'Completed' AND f.Quantity > 0 AND f.Unit_Price > 0
    GROUP BY d.[Year]
)
SELECT order_year,
       spend,
       LAG(spend) OVER (ORDER BY order_year) AS prior_year_spend,
       (spend - LAG(spend) OVER (ORDER BY order_year)) * 100.0
           / LAG(spend) OVER (ORDER BY order_year) AS yoy_pct_change
FROM yearly
ORDER BY order_year;
-- Result: 2024 = $247,848,263.50 | 2025 = $251,639,740.14 | +1.53% YoY.
-- This growth figure is understated, see sections 9 and 10.


-- ----------------------------------------------------------------------------
-- 3. Monthly spend trend
-- ----------------------------------------------------------------------------
SELECT d.Year_Month,
       SUM(f.Quantity * f.Unit_Price) AS spend,
       COUNT(DISTINCT f.PO_ID)        AS po_count
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_date d ON f.Order_Date = d.[Date]
WHERE f.PO_Status = 'Completed' AND f.Quantity > 0 AND f.Unit_Price > 0
GROUP BY d.Year_Month
ORDER BY d.Year_Month;
-- Result: 24 months. Monthly spend ranges $16.8M (Feb 2024) to $26.7M
-- (Mar 2025), 295-404 POs per month. Dec 2025 drops to $11.9M / 197 POs;
-- that is an end-of-data artifact, explained in section 9.


-- ----------------------------------------------------------------------------
-- 4. Spend by department, with share of total
-- SUM(SUM(...)) OVER () is a window function: the grand total across all
-- groups, so each row can show its percentage without a second query.
-- ----------------------------------------------------------------------------
SELECT dep.Department,
       dep.[Group],
       SUM(f.Quantity * f.Unit_Price) AS spend,
       SUM(f.Quantity * f.Unit_Price) * 100.0
           / SUM(SUM(f.Quantity * f.Unit_Price)) OVER () AS pct_of_total
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_department dep ON f.Department_ID = dep.Department_ID
WHERE f.PO_Status = 'Completed' AND f.Quantity > 0 AND f.Unit_Price > 0
GROUP BY dep.Department, dep.[Group]
ORDER BY spend DESC;
-- Result (share of total): Manufacturing 27.5% | Engineering 17.3% |
-- IT 12.9% | Operations 10.1% | Marketing 7.9% | Sales 7.3% | Finance 5.8% |
-- Human Resources 5.8% | Facilities 5.6%. Shares sum to 100%.


-- ----------------------------------------------------------------------------
-- 5. Spend by product category, with share of total
-- ----------------------------------------------------------------------------
SELECT p.Product_Category,
       SUM(f.Quantity * f.Unit_Price) AS spend,
       SUM(f.Quantity * f.Unit_Price) * 100.0
           / SUM(SUM(f.Quantity * f.Unit_Price)) OVER () AS pct_of_total
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_product p ON f.Product_ID = p.Product_ID
WHERE f.PO_Status = 'Completed' AND f.Quantity > 0 AND f.Unit_Price > 0
GROUP BY p.Product_Category
ORDER BY spend DESC;
-- Result (share of total): Manufacturing 40.6% | Software 27.9% |
-- Professional Services 10.4% | IT Equipment 9.9% | Office Supplies 4.4% |
-- Facilities 3.7% | Logistics 3.2%. Shares sum to 100%.


-- ----------------------------------------------------------------------------
-- 6. Top 10 subcategories by spend
-- ----------------------------------------------------------------------------
SELECT TOP 10
       p.Product_Category,
       p.Subcategory,
       SUM(f.Quantity * f.Unit_Price) AS spend
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_product p ON f.Product_ID = p.Product_ID
WHERE f.PO_Status = 'Completed' AND f.Quantity > 0 AND f.Unit_Price > 0
GROUP BY p.Product_Category, p.Subcategory
ORDER BY spend DESC;
-- Result: Manufacturing/Components $96.4M | Manufacturing/Production Supplies
-- $68.9M | Software/Security Licenses $44.5M | Software/Productivity Licenses
-- $43.4M | Software/Analytics Licenses $42.5M | Manufacturing/Equipment-Related
-- Purchases $37.6M | IT Equipment/Laptops $27.7M | Professional Services/
-- Consulting $24.4M | Office Supplies/Furniture $16.7M | Professional
-- Services/Technical Support $14.6M.


-- ----------------------------------------------------------------------------
-- 7. Category spend by year (which categories are growing or shrinking)
-- ----------------------------------------------------------------------------
SELECT p.Product_Category,
       d.[Year] AS order_year,
       SUM(f.Quantity * f.Unit_Price) AS spend
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_product p ON f.Product_ID = p.Product_ID
JOIN dbo.dim_date d ON f.Order_Date = d.[Date]
WHERE f.PO_Status = 'Completed' AND f.Quantity > 0 AND f.Unit_Price > 0
GROUP BY p.Product_Category, d.[Year]
ORDER BY p.Product_Category, d.[Year];
-- Result: 14 rows (7 categories x 2 years). Note: 2025 Completed spend is
-- understated by the end-of-data artifact (see section 9).


-- ----------------------------------------------------------------------------
-- 8. Reconciliation: do the pieces add up to the total?
-- Sections 2-3 use an INNER JOIN to dim_date, so rows with a NULL Order_Date
-- drop out of the time-based queries. This shows how much spend that is:
-- yearly spend + spend_with_missing_order_date should equal total_spend.
-- ----------------------------------------------------------------------------
SELECT SUM(Quantity * Unit_Price) AS total_spend,
       SUM(CASE WHEN Order_Date IS NULL THEN Quantity * Unit_Price ELSE 0 END)
           AS spend_with_missing_order_date
FROM dbo.fact_purchase_orders
WHERE PO_Status = 'Completed' AND Quantity > 0 AND Unit_Price > 0;
-- Result: total $499,651,571.54 | missing-date spend $163,567.90 (~0.03%).
-- Check: $247,848,263.50 + $251,639,740.14 + $163,567.90 = $499,651,571.54.


-- ----------------------------------------------------------------------------
-- 9. Completed vs Open spend by month
-- The Completed-only spend definition makes the most recent months look low,
-- because the dataset ends 2025-12-31 and recent orders haven't been
-- delivered yet. Treat the last 1-2 months of Completed spend as incomplete
-- when reading trends (see DECISIONS.md).
-- ----------------------------------------------------------------------------
SELECT d.Year_Month,
       SUM(CASE WHEN f.PO_Status = 'Completed' THEN f.Quantity * f.Unit_Price ELSE 0 END) AS completed_spend,
       SUM(CASE WHEN f.PO_Status = 'Open'      THEN f.Quantity * f.Unit_Price ELSE 0 END) AS open_spend
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_date d ON f.Order_Date = d.[Date]
WHERE f.PO_Status IN ('Completed', 'Open') AND f.Quantity > 0 AND f.Unit_Price > 0
GROUP BY d.Year_Month
ORDER BY d.Year_Month;
-- Result: Open spend is under ~$2.2M in almost every month through Oct 2025,
-- then $2.6M in Nov 2025 and $9.1M in Dec 2025. Dec 2025: Completed $11.9M +
-- Open $9.1M = ~$21.0M, in line with a normal month. Open lines in Dec 2025
-- jump to 387 (vs 30 in Sep), so the dip is undelivered orders, not lower buying.


-- ----------------------------------------------------------------------------
-- 10. Year-over-year on ordered spend (Completed + Open), as a cross-check
-- ----------------------------------------------------------------------------
SELECT d.[Year],
       SUM(f.Quantity * f.Unit_Price) AS ordered_spend
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_date d ON f.Order_Date = d.[Date]
WHERE f.PO_Status IN ('Completed', 'Open') AND f.Quantity > 0 AND f.Unit_Price > 0
GROUP BY d.[Year]
ORDER BY d.[Year];
-- Result: 2024 = $260,173,518.73 | 2025 = $272,185,723.63 | +4.62% YoY on
-- ordered spend (Completed + Open). Compare +1.53% on Completed-only spend
-- (section 2), which is understated by the end-of-data effect.