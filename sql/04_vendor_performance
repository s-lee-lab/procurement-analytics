-- ============================================================================
-- 04_vendor_performance.sql
-- Northstar Electronics — Procurement Analytics
-- Purpose: vendor questions from PROJECT_SPEC.md: who gets the most spend and
-- how concentrated is it, who delivers on time, and where are delays
-- concentrated. Reads from the cleaned dbo. tables. Nothing is modified here.
--
-- Spend rule (same as 03): PO_Status = 'Completed' AND Quantity > 0 AND
-- Unit_Price > 0.
-- Delivery rule (PROJECT_SPEC.md, line grain): PO_Status = 'Completed', valid
-- Expected and Actual dates, and Actual not before Order_Date (impossible).
-- Delivery KPIs do not apply the spend validity rule.
-- Caveats: only delivered (Completed) lines can be measured, so late orders
-- that are still Open don't count against anyone. Orders stop on 2025-12-31
-- but Completed deliveries run to 2026-04-19, and dim_date ends 2025-12-31,
-- so delivery dates are NOT joined to dim_date (see section 11 and
-- DECISIONS.md).
-- ============================================================================

USE NorthstarProcurement;
GO

-- ----------------------------------------------------------------------------
-- 0. Readiness check: how many Completed lines can be used for delivery KPIs?
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*) AS completed_lines,
    SUM(CASE WHEN Expected_Delivery_Date IS NULL THEN 1 ELSE 0 END) AS missing_expected,
    SUM(CASE WHEN Actual_Delivery_Date IS NULL THEN 1 ELSE 0 END) AS missing_actual,
    SUM(CASE WHEN Actual_Delivery_Date < Order_Date THEN 1 ELSE 0 END) AS delivery_before_order,
    SUM(CASE WHEN Expected_Delivery_Date IS NOT NULL
              AND Actual_Delivery_Date IS NOT NULL
              AND (Order_Date IS NULL OR Actual_Delivery_Date >= Order_Date)
             THEN 1 ELSE 0 END) AS valid_delivery_lines
FROM dbo.fact_purchase_orders
WHERE PO_Status = 'Completed';
-- Result: 17,739 Completed lines. 79 missing Expected date, 0 missing Actual,
-- 12 delivered before the order date. 17,648 usable delivery lines (99.5%).
-- 17,739 - 79 - 12 = 17,648, so the exclusions don't overlap.


-- ----------------------------------------------------------------------------
-- 1. Vendor spend ranking, share of total, and running (cumulative) share
-- ROWS UNBOUNDED PRECEDING makes the running total add one row at a time.
-- Without it, vendors with identical spend would be added together as a group.
-- ----------------------------------------------------------------------------
WITH vendor_spend AS (
    SELECT v.Vendor_ID, v.Vendor_Name, v.Vendor_Category, v.Region,
           SUM(f.Quantity * f.Unit_Price) AS spend,
           COUNT(DISTINCT f.PO_ID)        AS po_count,
           COUNT(*)                       AS line_count
    FROM dbo.fact_purchase_orders f
    JOIN dbo.dim_vendor v ON f.Vendor_ID = v.Vendor_ID
    WHERE f.PO_Status = 'Completed' AND f.Quantity > 0 AND f.Unit_Price > 0
    GROUP BY v.Vendor_ID, v.Vendor_Name, v.Vendor_Category, v.Region
)
SELECT ROW_NUMBER() OVER (ORDER BY spend DESC) AS spend_rank,
       Vendor_Name, Vendor_Category, Region, po_count, line_count, spend,
       spend * 100.0 / SUM(spend) OVER () AS pct_of_total,
       SUM(spend) OVER (ORDER BY spend DESC ROWS UNBOUNDED PRECEDING)
           * 100.0 / SUM(spend) OVER () AS cumulative_pct
FROM vendor_spend
ORDER BY spend DESC;
-- Result: 41 vendors. Largest: Keystone Manufacturing $44.98M (9.0%),
-- Harborview Components $41.57M (8.3%), Lakeside Cloud Systems $33.09M (6.6%).
-- Cumulative share: 56.8% at rank 10, 80.7% at rank 19, 100% at rank 41.
-- The top 10 are all Manufacturing (5) or Software (5).


-- ----------------------------------------------------------------------------
-- 2. Concentration summary: top-1 / top-5 / top-10 share, and HHI
-- HHI = sum of each vendor's squared share (in percent points). 41 equal
-- vendors would score about 244; one vendor with everything scores 10,000.
-- ----------------------------------------------------------------------------
WITH vendor_spend AS (
    SELECT Vendor_ID, SUM(Quantity * Unit_Price) AS spend
    FROM dbo.fact_purchase_orders
    WHERE PO_Status = 'Completed' AND Quantity > 0 AND Unit_Price > 0
    GROUP BY Vendor_ID
),
ranked AS (
    SELECT spend,
           ROW_NUMBER() OVER (ORDER BY spend DESC) AS rn,
           spend * 1.0 / SUM(spend) OVER ()        AS share
    FROM vendor_spend
)
SELECT SUM(CASE WHEN rn <= 1  THEN share ELSE 0 END) * 100 AS top1_pct,
       SUM(CASE WHEN rn <= 5  THEN share ELSE 0 END) * 100 AS top5_pct,
       SUM(CASE WHEN rn <= 10 THEN share ELSE 0 END) * 100 AS top10_pct,
       SUM(share * share) * 10000                          AS hhi
FROM ranked;
-- Result: top 1 = 9.00% | top 5 = 35.15% | top 10 = 56.78% | HHI = 439.3
-- (an even split across 41 vendors would be about 244). Moderately
-- concentrated, no dominant vendor.


-- ----------------------------------------------------------------------------
-- 3. Top 3 vendors within each product category (concentration inside a category)
-- ----------------------------------------------------------------------------
WITH cat_vendor AS (
    SELECT p.Product_Category, v.Vendor_Name,
           SUM(f.Quantity * f.Unit_Price) AS spend
    FROM dbo.fact_purchase_orders f
    JOIN dbo.dim_product p ON f.Product_ID = p.Product_ID
    JOIN dbo.dim_vendor  v ON f.Vendor_ID  = v.Vendor_ID
    WHERE f.PO_Status = 'Completed' AND f.Quantity > 0 AND f.Unit_Price > 0
    GROUP BY p.Product_Category, v.Vendor_Name
),
ranked AS (
    SELECT Product_Category, Vendor_Name, spend,
           spend * 100.0 / SUM(spend) OVER (PARTITION BY Product_Category) AS pct_of_category,
           RANK() OVER (PARTITION BY Product_Category ORDER BY spend DESC) AS rank_in_category
    FROM cat_vendor
)
SELECT Product_Category, rank_in_category, Vendor_Name, spend, pct_of_category
FROM ranked
WHERE rank_in_category <= 3
ORDER BY Product_Category, rank_in_category;
-- Result: leader's share of its category: Logistics/Meridian 37.9%,
-- Professional Services/Bright Path 36.6%, Facilities/Vertex 32.2%, Office
-- Supplies/Palisade 28.3%, Software/Lakeside 23.8%, IT Equipment/Anchor 22.4%,
-- Manufacturing/Keystone 22.2%. No leader above 40%. Relative to an even split
-- among that category's vendors, leaders sit at 1.4x-1.8x.

-- 3a. Sanity check: do vendors only sell inside their own category?
SELECT COUNT(*) AS completed_lines,
       SUM(CASE WHEN v.Vendor_Category <> p.Product_Category THEN 1 ELSE 0 END) AS cross_category_lines
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_product p ON f.Product_ID = p.Product_ID
JOIN dbo.dim_vendor  v ON f.Vendor_ID  = v.Vendor_ID
WHERE f.PO_Status = 'Completed';
-- Result: 0 of 17,739 lines cross categories.


-- ----------------------------------------------------------------------------
-- 4. Single-source products (bought from exactly one vendor)
-- 4a. How many products have 1, 2, 3... vendors, and how much spend each holds
-- ----------------------------------------------------------------------------
WITH product_vendors AS (
    SELECT Product_ID,
           COUNT(DISTINCT Vendor_ID)      AS n_vendors,
           SUM(Quantity * Unit_Price)     AS spend
    FROM dbo.fact_purchase_orders
    WHERE PO_Status = 'Completed' AND Quantity > 0 AND Unit_Price > 0
    GROUP BY Product_ID
)
SELECT n_vendors,
       COUNT(*) AS products,
       SUM(spend) AS spend,
       SUM(spend) * 100.0 / SUM(SUM(spend)) OVER () AS pct_of_spend
FROM product_vendors
GROUP BY n_vendors
ORDER BY n_vendors;
-- Result (all 107 products): 1 vendor = 8 products, $24.7M (4.9% of spend) |
-- 2 vendors = 20 products, $79.0M (15.8%) | 3 = 43, $218.3M (43.7%) |
-- 4 = 15, $67.8M (13.6%) | 5 = 21, $109.8M (22.0%).

-- 4b. The 10 biggest single-source products by spend
WITH product_vendors AS (
    SELECT Product_ID,
           MIN(Vendor_ID)                 AS Vendor_ID,
           COUNT(DISTINCT Vendor_ID)      AS n_vendors,
           SUM(Quantity * Unit_Price)     AS spend
    FROM dbo.fact_purchase_orders
    WHERE PO_Status = 'Completed' AND Quantity > 0 AND Unit_Price > 0
    GROUP BY Product_ID
)
SELECT TOP 10 p.Product_Name, p.Product_Category, v.Vendor_Name, pv.spend
FROM product_vendors pv
JOIN dbo.dim_product p ON pv.Product_ID = p.Product_ID
JOIN dbo.dim_vendor  v ON pv.Vendor_ID  = v.Vendor_ID
WHERE pv.n_vendors = 1
ORDER BY pv.spend DESC;
-- Result: only 8 single-source products exist (4a). Three hold ~87% of the
-- single-source spend: Strategy Consulting (Redwood, $7.77M), VPN License
-- (Lakeside, $7.55M), Systems Integration Consulting (Bright Path, $6.24M).
-- Investigation candidates only; sole-sourcing of consulting and licenses can
-- be normal, and the generator built single-source products in on purpose.


-- ----------------------------------------------------------------------------
-- 5. Delivery KPIs overall (PO-line grain)
-- On-Time Delivery % = lines delivered on/before expected date / valid lines.
-- Average Days Late = average delay over late lines only (AVG ignores the
-- NULLs that the CASE returns for on-time lines).
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS delivery_lines,
       SUM(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END)
           * 100.0 / COUNT(*) AS on_time_pct,
       AVG(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date
                THEN DATEDIFF(DAY, Expected_Delivery_Date, Actual_Delivery_Date) * 1.0 END)
           AS avg_days_late,
       MAX(DATEDIFF(DAY, Expected_Delivery_Date, Actual_Delivery_Date)) AS max_days_late
FROM dbo.fact_purchase_orders
WHERE PO_Status = 'Completed'
  AND Expected_Delivery_Date IS NOT NULL AND Actual_Delivery_Date IS NOT NULL
  AND (Order_Date IS NULL OR Actual_Delivery_Date >= Order_Date);
-- Result: 17,648 lines | on-time 75.84% | average 12.64 days late on late
-- lines | maximum 161 days late. Ties to section 0.


-- ----------------------------------------------------------------------------
-- 6. Vendor scorecard: spend share next to delivery performance
-- Two CTEs (spend and delivery) built with different rules, joined by vendor.
-- delivery_lines shows how much evidence is behind each on-time %.
-- ----------------------------------------------------------------------------
WITH spend AS (
    SELECT Vendor_ID, SUM(Quantity * Unit_Price) AS spend
    FROM dbo.fact_purchase_orders
    WHERE PO_Status = 'Completed' AND Quantity > 0 AND Unit_Price > 0
    GROUP BY Vendor_ID
),
delivery AS (
    SELECT Vendor_ID,
           COUNT(*) AS delivery_lines,
           SUM(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END)
               * 100.0 / COUNT(*) AS on_time_pct,
           AVG(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date
                    THEN DATEDIFF(DAY, Expected_Delivery_Date, Actual_Delivery_Date) * 1.0 END)
               AS avg_days_late
    FROM dbo.fact_purchase_orders
    WHERE PO_Status = 'Completed'
      AND Expected_Delivery_Date IS NOT NULL AND Actual_Delivery_Date IS NOT NULL
      AND (Order_Date IS NULL OR Actual_Delivery_Date >= Order_Date)
    GROUP BY Vendor_ID
)
SELECT v.Vendor_Name, v.Vendor_Category, v.Region,
       s.spend,
       s.spend * 100.0 / SUM(s.spend) OVER () AS pct_of_spend,
       d.delivery_lines, d.on_time_pct, d.avg_days_late
FROM dbo.dim_vendor v
LEFT JOIN spend    s ON v.Vendor_ID = s.Vendor_ID
LEFT JOIN delivery d ON v.Vendor_ID = d.Vendor_ID
ORDER BY d.on_time_pct ASC;
-- Result: 41 vendors; delivery_lines sum to 17,648. On-time ranges from 52.8%
-- (Oakridge Maintenance) to 97.2% (Brookfield Technologies). The 15 vendors
-- under 70% on-time hold 33.2% of spend. Largest vendor Keystone (9.0% of
-- spend) is on time 96.5%. Larger vendors with weak delivery: Kingsley (4.0%
-- of spend, 55.9% on time, 18.7 days late), Elmwood (5.3%, 68.6%, 22.2),
-- Lighthouse (5.1%, 68.2%), Lakeside (6.6%, 68.1%, 4.1). Per-vendor line
-- counts are 150-1,145, so small gaps between neighbors are noise.


-- ----------------------------------------------------------------------------
-- 7. Where are delays concentrated? By product category
-- ----------------------------------------------------------------------------
SELECT p.Product_Category,
       COUNT(*) AS delivery_lines,
       SUM(CASE WHEN f.Actual_Delivery_Date <= f.Expected_Delivery_Date THEN 1 ELSE 0 END)
           * 100.0 / COUNT(*) AS on_time_pct,
       AVG(CASE WHEN f.Actual_Delivery_Date > f.Expected_Delivery_Date
                THEN DATEDIFF(DAY, f.Expected_Delivery_Date, f.Actual_Delivery_Date) * 1.0 END)
           AS avg_days_late
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_product p ON f.Product_ID = p.Product_ID
WHERE f.PO_Status = 'Completed'
  AND f.Expected_Delivery_Date IS NOT NULL AND f.Actual_Delivery_Date IS NOT NULL
  AND (f.Order_Date IS NULL OR f.Actual_Delivery_Date >= f.Order_Date)
GROUP BY p.Product_Category
ORDER BY on_time_pct ASC;
-- Result: lines sum to 17,648. On-time from 66.1% (Facilities, 7.2 days late)
-- to 82.3% (Office Supplies); the other five are 73.0%-78.0%. All five
-- Facilities vendors are in the lower half of the section 6 table.


-- ----------------------------------------------------------------------------
-- 8. Delivery by department
-- ----------------------------------------------------------------------------
SELECT dep.Department,
       COUNT(*) AS delivery_lines,
       SUM(CASE WHEN f.Actual_Delivery_Date <= f.Expected_Delivery_Date THEN 1 ELSE 0 END)
           * 100.0 / COUNT(*) AS on_time_pct,
       AVG(CASE WHEN f.Actual_Delivery_Date > f.Expected_Delivery_Date
                THEN DATEDIFF(DAY, f.Expected_Delivery_Date, f.Actual_Delivery_Date) * 1.0 END)
           AS avg_days_late
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_department dep ON f.Department_ID = dep.Department_ID
WHERE f.PO_Status = 'Completed'
  AND f.Expected_Delivery_Date IS NOT NULL AND f.Actual_Delivery_Date IS NOT NULL
  AND (f.Order_Date IS NULL OR f.Actual_Delivery_Date >= f.Order_Date)
GROUP BY dep.Department
ORDER BY on_time_pct ASC;
-- Result: lines sum to 17,648. On-time from 71.6% (Facilities) to 79.0%
-- (Finance), a narrow ~7-point range.


-- ----------------------------------------------------------------------------
-- 9. Delivery by vendor region
-- ----------------------------------------------------------------------------
SELECT v.Region,
       COUNT(*) AS delivery_lines,
       SUM(CASE WHEN f.Actual_Delivery_Date <= f.Expected_Delivery_Date THEN 1 ELSE 0 END)
           * 100.0 / COUNT(*) AS on_time_pct,
       AVG(CASE WHEN f.Actual_Delivery_Date > f.Expected_Delivery_Date
                THEN DATEDIFF(DAY, f.Expected_Delivery_Date, f.Actual_Delivery_Date) * 1.0 END)
           AS avg_days_late
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_vendor v ON f.Vendor_ID = v.Vendor_ID
WHERE f.PO_Status = 'Completed'
  AND f.Expected_Delivery_Date IS NOT NULL AND f.Actual_Delivery_Date IS NOT NULL
  AND (f.Order_Date IS NULL OR f.Actual_Delivery_Date >= f.Order_Date)
GROUP BY v.Region
ORDER BY on_time_pct ASC;
-- Result: lines sum to 17,648. Midwest US is 88.2%; the other five regions are
-- 72.6%-76.1%. Midwest has only 3 vendors (Keystone, Redwood, Granite Freight;
-- 426 + 795 + 268 = 1,489 lines), so the region mostly reflects which vendors
-- are in it. Vendor spread (53%-97%) is far wider than category (16 points),
-- department (7 points) or region.


-- ----------------------------------------------------------------------------
-- 10. How late is late? Lateness buckets
-- ----------------------------------------------------------------------------
WITH lines AS (
    SELECT DATEDIFF(DAY, Expected_Delivery_Date, Actual_Delivery_Date) AS days_late
    FROM dbo.fact_purchase_orders
    WHERE PO_Status = 'Completed'
      AND Expected_Delivery_Date IS NOT NULL AND Actual_Delivery_Date IS NOT NULL
      AND (Order_Date IS NULL OR Actual_Delivery_Date >= Order_Date)
)
SELECT CASE WHEN days_late <= 0  THEN '1. On time or early'
            WHEN days_late <= 3  THEN '2. 1-3 days late'
            WHEN days_late <= 7  THEN '3. 4-7 days late'
            WHEN days_late <= 14 THEN '4. 8-14 days late'
            ELSE '5. 15+ days late' END AS bucket,
       COUNT(*) AS delivery_lines,
       COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS pct_of_lines
FROM lines
GROUP BY CASE WHEN days_late <= 0  THEN '1. On time or early'
              WHEN days_late <= 3  THEN '2. 1-3 days late'
              WHEN days_late <= 7  THEN '3. 4-7 days late'
              WHEN days_late <= 14 THEN '4. 8-14 days late'
              ELSE '5. 15+ days late' END
ORDER BY bucket;
-- Result: on time 13,384 (75.8%) | 1-3 days 1,142 (6.5%) | 4-7 days 952
-- (5.4%) | 8-14 days 950 (5.4%) | 15+ days 1,220 (6.9%). 4,264 late lines in
-- all; about half of them (2,170) are 8+ days late, so the 161-day maximum is
-- the end of a long tail, not a lone outlier.


-- ----------------------------------------------------------------------------
-- 11. On-time % by month of actual delivery
-- The month comes straight from the delivery date, not from dim_date: dim_date
-- ends 2025-12-31, and an inner join silently dropped the 158 lines delivered
-- in 2026. Dated by delivery month, so late-2025 orders that are still Open
-- don't distort it the way they did in 03.
-- ----------------------------------------------------------------------------
SELECT CONVERT(CHAR(7), f.Actual_Delivery_Date, 120) AS delivery_month,
       COUNT(*) AS delivery_lines,
       SUM(CASE WHEN f.Actual_Delivery_Date <= f.Expected_Delivery_Date THEN 1 ELSE 0 END)
           * 100.0 / COUNT(*) AS on_time_pct
FROM dbo.fact_purchase_orders f
WHERE f.PO_Status = 'Completed'
  AND f.Expected_Delivery_Date IS NOT NULL AND f.Actual_Delivery_Date IS NOT NULL
  AND (f.Order_Date IS NULL OR f.Actual_Delivery_Date >= f.Order_Date)
GROUP BY CONVERT(CHAR(7), f.Actual_Delivery_Date, 120)
ORDER BY delivery_month;
-- Result: 28 months, 17,648 lines (24 months to 2025-12 = 17,490, plus 158 in
-- 2026). 2024-02 through 2025-11 stay between 73.6% and 78.7% with no trend.
-- 2024-01 (81.4%) has only 479 lines; 2025-12 is 71.0% on 556 lines. 2026:
-- Jan 133 lines (54.1%), Feb 22 (18.2%), Mar 1 (0%), Apr 2 (0%); latest
-- delivery 2026-04-19. These look like late-2025 orders that slipped past
-- year-end; the sample is small, so treat the 2026 and end-of-window months
-- with caution.


-- ----------------------------------------------------------------------------
-- 12. Open lines already past their expected date
-- Not a delivery KPI (these lines are undelivered); a pipeline/risk view.
-- ASSUMPTION: the data has no snapshot date, so "as of" is the latest
-- Completed delivery date (2026-04-19), a lower bound for the true snapshot.
-- Select the DECLARE together with the queries below.
-- ----------------------------------------------------------------------------
DECLARE @as_of DATE = (SELECT MAX(Actual_Delivery_Date)
                       FROM dbo.fact_purchase_orders
                       WHERE PO_Status = 'Completed');

-- 12a. How overdue are they?
SELECT CASE WHEN DATEDIFF(DAY, Expected_Delivery_Date, @as_of) <= 30  THEN '1. 1-30 days overdue'
            WHEN DATEDIFF(DAY, Expected_Delivery_Date, @as_of) <= 90  THEN '2. 31-90 days overdue'
            WHEN DATEDIFF(DAY, Expected_Delivery_Date, @as_of) <= 180 THEN '3. 91-180 days overdue'
            ELSE '4. 180+ days overdue' END AS bucket,
       COUNT(*) AS open_lines,
       SUM(Quantity * Unit_Price) AS open_spend
FROM dbo.fact_purchase_orders
WHERE PO_Status = 'Open' AND Expected_Delivery_Date < @as_of
  AND Quantity > 0 AND Unit_Price > 0
GROUP BY CASE WHEN DATEDIFF(DAY, Expected_Delivery_Date, @as_of) <= 30  THEN '1. 1-30 days overdue'
              WHEN DATEDIFF(DAY, Expected_Delivery_Date, @as_of) <= 90  THEN '2. 31-90 days overdue'
              WHEN DATEDIFF(DAY, Expected_Delivery_Date, @as_of) <= 180 THEN '3. 91-180 days overdue'
              ELSE '4. 180+ days overdue' END
ORDER BY bucket;

-- 12b. Which vendors hold the most overdue Open spend?
SELECT TOP 10 v.Vendor_Name,
       COUNT(*) AS overdue_open_lines,
       SUM(f.Quantity * f.Unit_Price) AS open_spend_overdue
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_vendor v ON f.Vendor_ID = v.Vendor_ID
WHERE f.PO_Status = 'Open' AND f.Expected_Delivery_Date < @as_of
  AND f.Quantity > 0 AND f.Unit_Price > 0
GROUP BY v.Vendor_Name
ORDER BY open_spend_overdue DESC;
-- Result (earlier version, measured against 2025-12-31): top 10 vendors hold
-- about $16.2M of overdue Open spend, led by Sterling Software ($2.44M),
-- Keystone ($2.33M), Trailhead ($2.08M), Lakeside ($2.08M). Ranked by dollars,
-- so it mostly tracks vendor size. (Run the 2026-04-19 version above and paste
-- its results here.)