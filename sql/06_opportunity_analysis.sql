/* =====================================================================
   06_opportunity_analysis.sql
   Pulls pricing (05) and delivery (04) together into investigation
   candidates. Read-only; builds temp tables only. Self-contained: run
   top to bottom in ONE query window.

   Contents
     1. Price-leakage savings, sized low / base / high (ASSUMPTIONS)
     2. Supplier scorecard (weighted composite; weights set below)
     3. Price x on-time quadrants
     4. Overdue Open-line exception report (ILLUSTRATIVE - see DECISIONS.md,
        2026-11-10: Open status is a generator artifact)
     5. Tail spend
     6. Headline numbers for the README / executive brief

   Important framing (PROJECT_SPEC.md): everything here is an investigation
   candidate, not a verified saving. Savings ranges are assumptions applied
   to synthetic data. Delivery risk is NOT given a dollar value: the data
   has no delay-cost field.
   ===================================================================== */

/* ---- Assumptions: change here, nowhere else ------------------------ */
DECLARE @min_lines      INT          = 30;    -- min valid lines per product for a stable median
DECLARE @pair_min_lines INT          = 10;    -- min lines per vendor-product pair to flag
DECLARE @price_flag     DECIMAL(5,3) = 1.05;  -- pair price index above this = flagged
DECLARE @r_low          DECIMAL(4,2) = 0.25;  -- share of the price gap assumed recovered
DECLARE @r_base         DECIMAL(4,2) = 0.50;
DECLARE @r_high         DECIMAL(4,2) = 0.75;
DECLARE @w_ontime       DECIMAL(4,2) = 0.40;  -- scorecard weights (must total 1.00)
DECLARE @w_late         DECIMAL(4,2) = 0.20;
DECLARE @w_price        DECIMAL(4,2) = 0.30;
DECLARE @w_conc         DECIMAL(4,2) = 0.10;
DECLARE @as_of          DATE         = '2025-12-31';  -- reference date for Open-line aging

SELECT @w_ontime + @w_late + @w_price + @w_conc AS weight_total_must_be_1;

/* ---------------------------------------------------------------------
   0. Working sets (same rules as 04 and 05)
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS #pb;
DROP TABLE IF EXISTS #ot;
DROP TABLE IF EXISTS #pair;
DROP TABLE IF EXISTS #vs;

-- Price side: valid Completed lines with product-level median benchmark
WITH base AS (
    SELECT f.Vendor_ID, f.Product_ID, f.Quantity, f.Unit_Price,
           f.Quantity * f.Unit_Price AS line_spend,
           PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.Unit_Price)
               OVER (PARTITION BY f.Product_ID) AS benchmark_price,
           COUNT(*) OVER (PARTITION BY f.Product_ID) AS product_lines
    FROM dbo.fact_purchase_orders f
    WHERE f.PO_Status = 'Completed'
      AND f.Quantity > 0 AND f.Unit_Price > 0
)
SELECT Vendor_ID, Product_ID, Quantity, Unit_Price, line_spend, product_lines,
       benchmark_price * Quantity                 AS benchmark_spend,
       (Unit_Price - benchmark_price) * Quantity  AS ppv
INTO #pb
FROM base;

-- Delivery side: Completed lines with valid dates, line grain
SELECT Vendor_ID,
       COUNT(*) AS delivery_lines,
       SUM(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END) AS on_time_lines,
       SUM(CASE WHEN Actual_Delivery_Date >  Expected_Delivery_Date THEN 1 ELSE 0 END) AS late_lines,
       SUM(CASE WHEN Actual_Delivery_Date >  Expected_Delivery_Date
                THEN DATEDIFF(DAY, Expected_Delivery_Date, Actual_Delivery_Date) ELSE 0 END) AS late_days
INTO #ot
FROM dbo.fact_purchase_orders
WHERE PO_Status = 'Completed'
  AND Expected_Delivery_Date IS NOT NULL
  AND Actual_Delivery_Date  IS NOT NULL
  AND (Order_Date IS NULL OR Actual_Delivery_Date >= Order_Date)
GROUP BY Vendor_ID;

-- Reconciliation checks
SELECT SUM(line_spend) AS total_spend_expect_499651571_54 FROM #pb;
SELECT SUM(delivery_lines) AS delivery_lines_expect_17648,
       CAST(100.0 * SUM(on_time_lines) / SUM(delivery_lines) AS DECIMAL(5,1)) AS on_time_pct_expect_75_8,
       CAST(1.0 * SUM(late_days) / SUM(late_lines) AS DECIMAL(5,1)) AS avg_days_late_expect_about_12_6
FROM #ot;

/* ---------------------------------------------------------------------
   1. Price-leakage opportunity
      Flag vendor-product pairs (10+ lines) priced above the product median
      by more than 5% (spend-weighted). gap = total dollars paid above the
      median for the pair. The gap is a CEILING; low/base/high assume only
      25% / 50% / 75% of it is recovered through negotiation. Assumptions,
      not findings.
   --------------------------------------------------------------------- */
SELECT Product_ID, Vendor_ID,
       COUNT(*)         AS lines,
       SUM(line_spend)  AS spend,
       SUM(benchmark_spend) AS bench_spend,
       SUM(ppv)         AS gap
INTO #pair
FROM #pb
WHERE product_lines >= @min_lines
GROUP BY Product_ID, Vendor_ID
HAVING COUNT(*) >= @pair_min_lines
   AND SUM(line_spend) / SUM(benchmark_spend) > @price_flag;

/* 1a. Summary */
SELECT COUNT(*)                    AS flagged_pairs,
       COUNT(DISTINCT Vendor_ID)   AS vendors,
       COUNT(DISTINCT Product_ID)  AS products,
       CAST(SUM(spend) AS DECIMAL(18,2))              AS spend_in_flagged_pairs,
       CAST(SUM(gap) AS DECIMAL(18,2))                AS gap_ceiling,
       CAST(SUM(gap) * @r_low  AS DECIMAL(18,2))      AS savings_low,
       CAST(SUM(gap) * @r_base AS DECIMAL(18,2))      AS savings_base,
       CAST(SUM(gap) * @r_high AS DECIMAL(18,2))      AS savings_high,
       CAST(100.0 * SUM(gap) / (SELECT SUM(line_spend) FROM #pb) AS DECIMAL(5,2)) AS ceiling_pct_of_total_spend
FROM #pair;

/* 1b. By vendor (top 10 by gap), with on-time % alongside */
SELECT TOP 10
       v.Vendor_Name,
       COUNT(*)                                       AS flagged_products,
       CAST(SUM(p.spend) AS DECIMAL(18,2))            AS spend,
       CAST(SUM(p.gap) AS DECIMAL(18,2))              AS gap_ceiling,
       CAST(SUM(p.gap) * @r_base AS DECIMAL(18,2))    AS savings_base,
       CAST(100.0 * o.on_time_lines / o.delivery_lines AS DECIMAL(5,1)) AS on_time_pct
FROM #pair p
JOIN dbo.dim_vendor v ON p.Vendor_ID = v.Vendor_ID
JOIN #ot o            ON p.Vendor_ID = o.Vendor_ID
GROUP BY v.Vendor_ID, v.Vendor_Name, o.on_time_lines, o.delivery_lines
ORDER BY gap_ceiling DESC;

/* 1c. By category */
SELECT d.Product_Category,
       COUNT(*)                                    AS flagged_pairs,
       CAST(SUM(p.spend) AS DECIMAL(18,2))         AS spend,
       CAST(SUM(p.gap) AS DECIMAL(18,2))           AS gap_ceiling,
       CAST(SUM(p.gap) * @r_base AS DECIMAL(18,2)) AS savings_base
FROM #pair p
JOIN dbo.dim_product d ON p.Product_ID = d.Product_ID
GROUP BY d.Product_Category
ORDER BY gap_ceiling DESC;

/* 1d. Reliability-adjusted base case: drop vendors that are 85%+ on-time,
       since a price premium may be buying reliability (e.g. Keystone) */
SELECT CAST(SUM(p.gap) * @r_base AS DECIMAL(18,2)) AS savings_base_excl_reliable_vendors
FROM #pair p
JOIN #ot o ON p.Vendor_ID = o.Vendor_ID
WHERE 100.0 * o.on_time_lines / o.delivery_lines < 85;

/* ---------------------------------------------------------------------
   2. Supplier scorecard
      Each metric rescaled 0-100 (min-max across the 41 vendors; 100 = best),
      then weighted. Metrics: on-time % (higher better), average days late
      when late (lower better), price index vs. product median (lower
      better), vendor share of total spend (lower = less concentration
      risk). Weights in the assumptions block. Price and on-time are
      uncorrelated in this data (DECISIONS.md, 2026-11-10), so they carry
      independent information.
   --------------------------------------------------------------------- */
WITH px AS (
    SELECT Vendor_ID,
           SUM(line_spend) AS spend,
           SUM(line_spend) / SUM(benchmark_spend) AS price_index
    FROM #pb
    WHERE product_lines >= @min_lines
    GROUP BY Vendor_ID
),
m AS (
    SELECT px.Vendor_ID, px.spend,
           px.spend / SUM(px.spend) OVER ()                      AS spend_share,
           px.price_index,
           100.0 * o.on_time_lines / o.delivery_lines            AS on_time_pct,
           CASE WHEN o.late_lines > 0 THEN 1.0 * o.late_days / o.late_lines ELSE 0 END AS avg_days_late,
           CASE WHEN px.price_index > 1.05 THEN 'Above benchmark'
                WHEN px.price_index < 0.95 THEN 'Below benchmark'
                ELSE 'At benchmark' END                          AS price_band,
           CASE WHEN 100.0 * o.on_time_lines / o.delivery_lines < 70 THEN 'Weak (<70%)'
                WHEN 100.0 * o.on_time_lines / o.delivery_lines >= 85 THEN 'Strong (85%+)'
                ELSE 'Mid (70-85%)' END                          AS delivery_band
    FROM px
    JOIN #ot o ON px.Vendor_ID = o.Vendor_ID
)
SELECT m.*,
       100.0 * (m.on_time_pct - MIN(m.on_time_pct) OVER ())
             / NULLIF(MAX(m.on_time_pct) OVER () - MIN(m.on_time_pct) OVER (), 0)       AS s_ontime,
       100.0 * (MAX(m.avg_days_late) OVER () - m.avg_days_late)
             / NULLIF(MAX(m.avg_days_late) OVER () - MIN(m.avg_days_late) OVER (), 0)   AS s_late,
       100.0 * (MAX(m.price_index) OVER () - m.price_index)
             / NULLIF(MAX(m.price_index) OVER () - MIN(m.price_index) OVER (), 0)       AS s_price,
       100.0 * (MAX(m.spend_share) OVER () - m.spend_share)
             / NULLIF(MAX(m.spend_share) OVER () - MIN(m.spend_share) OVER (), 0)       AS s_conc
INTO #vs
FROM m;

SELECT RANK() OVER (ORDER BY x.composite DESC) AS score_rank,
       v.Vendor_Name,
       CAST(x.composite AS DECIMAL(5,1))        AS composite_score,
       CAST(x.spend / 1000000.0 AS DECIMAL(8,2)) AS spend_millions,
       CAST(100.0 * x.spend_share AS DECIMAL(5,2)) AS spend_share_pct,
       CAST(x.on_time_pct AS DECIMAL(5,1))      AS on_time_pct,
       CAST(x.avg_days_late AS DECIMAL(5,1))    AS avg_days_late,
       CAST(x.price_index AS DECIMAL(6,4))      AS price_index,
       x.price_band, x.delivery_band
FROM (SELECT vs.*,
             @w_ontime * s_ontime + @w_late * s_late + @w_price * s_price + @w_conc * s_conc AS composite
      FROM #vs vs) x
JOIN dbo.dim_vendor v ON x.Vendor_ID = v.Vendor_ID
ORDER BY score_rank;

/* ---------------------------------------------------------------------
   3. Price x on-time quadrants
   --------------------------------------------------------------------- */
SELECT price_band, delivery_band,
       COUNT(*) AS vendors,
       CAST(SUM(spend) AS DECIMAL(18,2)) AS spend,
       CAST(100.0 * SUM(spend) / SUM(SUM(spend)) OVER () AS DECIMAL(5,1)) AS pct_of_spend
FROM #vs
GROUP BY price_band, delivery_band
ORDER BY price_band, delivery_band;

/* 3b. The cell that matters: above benchmark AND weak delivery
       (expect Lakeside, Lighthouse, Pinnacle, Anchor, Ironclad, ~$89.8M) */
SELECT v.Vendor_Name,
       CAST(vs.spend AS DECIMAL(18,2))     AS spend,
       CAST(vs.price_index AS DECIMAL(6,4)) AS price_index,
       CAST(vs.on_time_pct AS DECIMAL(5,1)) AS on_time_pct
FROM #vs vs
JOIN dbo.dim_vendor v ON vs.Vendor_ID = v.Vendor_ID
WHERE vs.price_band = 'Above benchmark' AND vs.delivery_band = 'Weak (<70%)'
ORDER BY vs.spend DESC;

/* ---------------------------------------------------------------------
   4. Overdue Open-line exception report (ILLUSTRATIVE)
      Open lines with an Expected date earlier than @as_of. Status in the
      synthetic data is assigned by order recency, not vendor behavior, so
      these are a method demonstration, not a backlog finding.
   --------------------------------------------------------------------- */
/* 4a. Aging buckets (expect 151 / 260 / 103 / 100 / 602 lines at 2025-12-31) */
WITH ol AS (
    SELECT Quantity * Unit_Price AS line_value,
           DATEDIFF(DAY, Expected_Delivery_Date, @as_of) AS days_overdue
    FROM dbo.fact_purchase_orders
    WHERE PO_Status = 'Open' AND Quantity > 0 AND Unit_Price > 0
      AND Expected_Delivery_Date IS NOT NULL
)
SELECT CASE WHEN days_overdue <= 0   THEN '0. Not yet due'
            WHEN days_overdue <= 30  THEN '1. 1-30 days overdue'
            WHEN days_overdue <= 90  THEN '2. 31-90 days overdue'
            WHEN days_overdue <= 180 THEN '3. 91-180 days overdue'
            ELSE '4. 180+ days overdue' END AS bucket,
       COUNT(*) AS open_lines,
       CAST(SUM(line_value) AS DECIMAL(18,2)) AS open_spend
FROM ol
GROUP BY CASE WHEN days_overdue <= 0   THEN '0. Not yet due'
              WHEN days_overdue <= 30  THEN '1. 1-30 days overdue'
              WHEN days_overdue <= 90  THEN '2. 31-90 days overdue'
              WHEN days_overdue <= 180 THEN '3. 91-180 days overdue'
              ELSE '4. 180+ days overdue' END
ORDER BY bucket;

/* 4b. The 25 largest overdue Open lines */
SELECT TOP 25
       f.PO_ID, f.PO_Line_ID, v.Vendor_Name, p.Product_Name,
       f.Expected_Delivery_Date,
       DATEDIFF(DAY, f.Expected_Delivery_Date, @as_of) AS days_overdue,
       CAST(f.Quantity * f.Unit_Price AS DECIMAL(18,2)) AS line_value
FROM dbo.fact_purchase_orders f
JOIN dbo.dim_vendor  v ON f.Vendor_ID  = v.Vendor_ID
JOIN dbo.dim_product p ON f.Product_ID = p.Product_ID
WHERE f.PO_Status = 'Open' AND f.Quantity > 0 AND f.Unit_Price > 0
  AND f.Expected_Delivery_Date IS NOT NULL
  AND f.Expected_Delivery_Date < @as_of
ORDER BY f.Quantity * f.Unit_Price DESC;

/* ---------------------------------------------------------------------
   5. Tail spend: how many vendors make up the bottom 20% of spend?
      (04 found 19 vendors cover 80%, so expect a 22-vendor tail)
   --------------------------------------------------------------------- */
WITH v AS (
    SELECT Vendor_ID, SUM(line_spend) AS spend FROM #pb GROUP BY Vendor_ID
),
r AS (
    SELECT spend,
           SUM(spend) OVER (ORDER BY spend DESC ROWS UNBOUNDED PRECEDING) / SUM(spend) OVER () AS cum_share,
           spend / SUM(spend) OVER () AS share
    FROM v
)
SELECT CASE WHEN cum_share - share >= 0.80 THEN 'Tail (bottom 20% of spend)' ELSE 'Head (top 80% of spend)' END AS segment,
       COUNT(*) AS vendors,
       CAST(SUM(spend) AS DECIMAL(18,2)) AS spend,
       CAST(100.0 * SUM(share) AS DECIMAL(5,1)) AS pct_of_spend,
       CAST(AVG(spend) AS DECIMAL(18,2)) AS avg_spend_per_vendor
FROM r
GROUP BY CASE WHEN cum_share - share >= 0.80 THEN 'Tail (bottom 20% of spend)' ELSE 'Head (top 80% of spend)' END;

/* ---------------------------------------------------------------------
   6. Headline numbers (README / executive brief)
   --------------------------------------------------------------------- */
SELECT metric, value
FROM (VALUES
    ('Total completed spend ($)',
        (SELECT CAST(SUM(line_spend) AS DECIMAL(18,2)) FROM #pb)),
    ('Flagged vendor-product pairs (count)',
        (SELECT CAST(COUNT(*) AS DECIMAL(18,2)) FROM #pair)),
    ('Price-leakage ceiling ($)',
        (SELECT CAST(SUM(gap) AS DECIMAL(18,2)) FROM #pair)),
    ('Savings low, 25% realization ($)',
        (SELECT CAST(SUM(gap) * @r_low  AS DECIMAL(18,2)) FROM #pair)),
    ('Savings base, 50% realization ($)',
        (SELECT CAST(SUM(gap) * @r_base AS DECIMAL(18,2)) FROM #pair)),
    ('Savings high, 75% realization ($)',
        (SELECT CAST(SUM(gap) * @r_high AS DECIMAL(18,2)) FROM #pair)),
    ('Vendors under 70% on-time (count)',
        (SELECT CAST(COUNT(*) AS DECIMAL(18,2)) FROM #vs WHERE delivery_band = 'Weak (<70%)')),
    ('Spend with vendors under 70% on-time (% of spend)',
        (SELECT CAST(100.0 * SUM(spend) / (SELECT SUM(spend) FROM #vs) AS DECIMAL(18,2))
         FROM #vs WHERE delivery_band = 'Weak (<70%)')),
    ('Vendors above benchmark AND under 70% on-time (count)',
        (SELECT CAST(COUNT(*) AS DECIMAL(18,2)) FROM #vs
         WHERE price_band = 'Above benchmark' AND delivery_band = 'Weak (<70%)')),
    ('Spend with those vendors ($)',
        (SELECT CAST(SUM(spend) AS DECIMAL(18,2)) FROM #vs
         WHERE price_band = 'Above benchmark' AND delivery_band = 'Weak (<70%)'))
) AS t(metric, value);
