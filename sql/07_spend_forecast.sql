/* =====================================================================
   07_spend_forecast.sql
   Simple monthly spend forecast with an honest backtest.

   What is forecast: ORDERED spend by Order_Date month = Completed + Open
   lines (Cancelled excluded), valid lines only (Quantity > 0 AND
   Unit_Price > 0), lines with no Order_Date excluded. Ordered spend is
   used instead of Completed-only spend because Completed-only spend dips
   at the end of the data window (DECISIONS.md, 2026-10-26).

   Method: six deliberately simple baselines. The point of this script is
   backtesting discipline, not predictive power: there are only 24 monthly
   points, so a method has to beat the naive benchmarks to earn a place.
     naive_last       last observed month, held flat
     ma3              average of the last 3 months, held flat
     ma6              average of the last 6 months, held flat
     mean_all         average of all training months, held flat
     seasonal_naive   same month one year earlier
     seasonal_growth  seasonal_naive x (last-6-month sum / same 6 months a
                      year earlier); needs 18+ months of history, so it is
                      only testable at the later backtest origin

   Backtests (6 months ahead each, matching how the final forecast is used):
     origin 12: train 2024-01..2024-12, test 2025-01..2025-06  (same half-year
                as the final forecast horizon)
     origin 18: train 2024-01..2025-06, test 2025-07..2025-12
   Seasonality is only repeatable in Jul-Dec (see Section 2), so a single
   Jul-Dec holdout would flatter seasonal methods; both origins are used.
   Final forecast: refit on all 24 months, forecast 2026-01..2026-06.

   Caveats: synthetic data; 12 holdout points in total; choosing a method
   after seeing the holdout is mildly optimistic; the forecast is a method
   demonstration, not a budget.
   ===================================================================== */

DECLARE @selected VARCHAR(20) = 'ma6';   -- final-forecast method; see the selection rule in Section 4

DROP TABLE IF EXISTS #m0;
DROP TABLE IF EXISTS #m;
DROP TABLE IF EXISTS #origin;
DROP TABLE IF EXISTS #fc;
DROP TABLE IF EXISTS #bt;
DROP TABLE IF EXISTS #bt_pooled;

/* ---------------------------------------------------------------------
   0. Monthly ordered spend
   --------------------------------------------------------------------- */
SELECT DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1) AS month_start,
       CAST(SUM(Quantity * Unit_Price) AS DECIMAL(18,2))     AS ordered_spend
INTO #m0
FROM dbo.fact_purchase_orders
WHERE PO_Status IN ('Completed', 'Open')
  AND Quantity > 0 AND Unit_Price > 0
  AND Order_Date IS NOT NULL
GROUP BY DATEFROMPARTS(YEAR(Order_Date), MONTH(Order_Date), 1);

SELECT month_start, ordered_spend,
       ROW_NUMBER() OVER (ORDER BY month_start) AS idx
INTO #m
FROM #m0;

/* Checks: expect 24 months, 2024-01-01 to 2025-12-01, no gaps;
   yearly totals about $260.17M (2024) and $272.19M (2025) per 03 Section 10 */
SELECT COUNT(*) AS months, MIN(month_start) AS first_month, MAX(month_start) AS last_month,
       DATEDIFF(MONTH, MIN(month_start), MAX(month_start)) + 1 AS months_if_no_gaps
FROM #m;

SELECT YEAR(month_start) AS yr, CAST(SUM(ordered_spend) AS DECIMAL(18,2)) AS ordered_spend
FROM #m GROUP BY YEAR(month_start) ORDER BY yr;

/* ---------------------------------------------------------------------
   1. The series: month-over-month and year-over-year change
   --------------------------------------------------------------------- */
SELECT month_start, ordered_spend,
       CAST(100.0 * (ordered_spend / LAG(ordered_spend)     OVER (ORDER BY idx) - 1) AS DECIMAL(6,1)) AS mom_pct,
       CAST(100.0 * (ordered_spend / LAG(ordered_spend, 12) OVER (ORDER BY idx) - 1) AS DECIMAL(6,1)) AS yoy_pct
FROM #m
ORDER BY idx;

/* ---------------------------------------------------------------------
   2. Is there seasonality? Each month relative to its own year's monthly
      average; if the two columns move together, a seasonal method has
      something to work with. (Correlation of the two columns: compute
      from this output; check Jan-Jun and Jul-Dec separately.)
   --------------------------------------------------------------------- */
WITH y AS (
    SELECT YEAR(month_start) AS yr, MONTH(month_start) AS mo,
           ordered_spend / AVG(ordered_spend) OVER (PARTITION BY YEAR(month_start)) AS rel
    FROM #m
)
SELECT mo,
       CAST(MAX(CASE WHEN yr = 2024 THEN rel END) AS DECIMAL(6,3)) AS rel_2024,
       CAST(MAX(CASE WHEN yr = 2025 THEN rel END) AS DECIMAL(6,3)) AS rel_2025
FROM y
GROUP BY mo
ORDER BY mo;

/* ---------------------------------------------------------------------
   3. Forecasts: two backtest origins (train through month 12 and 18) and
      the final origin (train through month 24), 6 months ahead each
   --------------------------------------------------------------------- */
CREATE TABLE #origin (train_end INT, purpose VARCHAR(10));
INSERT INTO #origin VALUES (12, 'backtest'), (18, 'backtest'), (24, 'final');

WITH h AS (SELECT n FROM (VALUES (1), (2), (3), (4), (5), (6)) AS v(n))
SELECT o.purpose, o.train_end, h.n AS horizon,
       o.train_end + h.n AS target_idx,
       DATEADD(MONTH, o.train_end + h.n - 1, (SELECT MIN(month_start) FROM #m)) AS target_month,
       (SELECT ordered_spend FROM #m WHERE idx = o.train_end)                                   AS naive_last,
       (SELECT AVG(ordered_spend) FROM #m WHERE idx BETWEEN o.train_end - 2 AND o.train_end)    AS ma3,
       (SELECT AVG(ordered_spend) FROM #m WHERE idx BETWEEN o.train_end - 5 AND o.train_end)    AS ma6,
       (SELECT AVG(ordered_spend) FROM #m WHERE idx <= o.train_end)                             AS mean_all,
       (SELECT ordered_spend FROM #m WHERE idx = o.train_end + h.n - 12)                        AS seasonal_naive,
       -- NULL at origin 12: growth needs 18+ months of history
       (SELECT ordered_spend FROM #m WHERE idx = o.train_end + h.n - 12)
         * (SELECT SUM(ordered_spend) FROM #m WHERE idx BETWEEN o.train_end - 5  AND o.train_end)
         / (SELECT SUM(ordered_spend) FROM #m WHERE idx BETWEEN o.train_end - 17 AND o.train_end - 12) AS seasonal_growth
INTO #fc
FROM #origin o
CROSS JOIN h;

/* 3a. Backtests, month by month ($ millions) */
SELECT f.train_end, f.horizon, f.target_month,
       CAST(m.ordered_spend    / 1000000.0 AS DECIMAL(8,2)) AS actual_m,
       CAST(f.naive_last       / 1000000.0 AS DECIMAL(8,2)) AS naive_last_m,
       CAST(f.ma3              / 1000000.0 AS DECIMAL(8,2)) AS ma3_m,
       CAST(f.ma6              / 1000000.0 AS DECIMAL(8,2)) AS ma6_m,
       CAST(f.mean_all         / 1000000.0 AS DECIMAL(8,2)) AS mean_all_m,
       CAST(f.seasonal_naive   / 1000000.0 AS DECIMAL(8,2)) AS seasonal_naive_m,
       CAST(f.seasonal_growth  / 1000000.0 AS DECIMAL(8,2)) AS seasonal_growth_m
FROM #fc f
JOIN #m m ON m.idx = f.target_idx
WHERE f.purpose = 'backtest'
ORDER BY f.target_idx;

/* 3b. Accuracy by method and origin.
       MAPE = mean absolute % error; WAPE = total absolute error / total actual;
       bias = mean signed % error (positive = over-forecast); MAE in dollars. */
SELECT f.train_end, x.method,
       COUNT(x.fc) AS months,
       CAST(100.0 * AVG(ABS(x.fc - m.ordered_spend) / m.ordered_spend)        AS DECIMAL(6,2)) AS mape_pct,
       CAST(100.0 * SUM(ABS(x.fc - m.ordered_spend)) / SUM(m.ordered_spend)   AS DECIMAL(6,2)) AS wape_pct,
       CAST(100.0 * AVG((x.fc - m.ordered_spend) / m.ordered_spend)           AS DECIMAL(6,2)) AS bias_pct,
       CAST(AVG(ABS(x.fc - m.ordered_spend))                                  AS DECIMAL(18,2)) AS mae
INTO #bt
FROM #fc f
JOIN #m m ON m.idx = f.target_idx
CROSS APPLY (VALUES ('naive_last',      f.naive_last),
                    ('ma3',             f.ma3),
                    ('ma6',             f.ma6),
                    ('mean_all',        f.mean_all),
                    ('seasonal_naive',  f.seasonal_naive),
                    ('seasonal_growth', f.seasonal_growth)) AS x(method, fc)
WHERE f.purpose = 'backtest' AND x.fc IS NOT NULL
GROUP BY f.train_end, x.method;

SELECT * FROM #bt ORDER BY train_end, wape_pct;

/* 3c. Pooled across both origins (12 months for every method except
       seasonal_growth, which only has the later 6 and is not comparable) */
SELECT x.method,
       COUNT(x.fc) AS months,
       CAST(100.0 * AVG(ABS(x.fc - m.ordered_spend) / m.ordered_spend)        AS DECIMAL(6,2)) AS mape_pct,
       CAST(100.0 * SUM(ABS(x.fc - m.ordered_spend)) / SUM(m.ordered_spend)   AS DECIMAL(6,2)) AS wape_pct,
       CAST(100.0 * AVG((x.fc - m.ordered_spend) / m.ordered_spend)           AS DECIMAL(6,2)) AS bias_pct,
       CAST(AVG(ABS(x.fc - m.ordered_spend))                                  AS DECIMAL(18,2)) AS mae
INTO #bt_pooled
FROM #fc f
JOIN #m m ON m.idx = f.target_idx
CROSS APPLY (VALUES ('naive_last',      f.naive_last),
                    ('ma3',             f.ma3),
                    ('ma6',             f.ma6),
                    ('mean_all',        f.mean_all),
                    ('seasonal_naive',  f.seasonal_naive),
                    ('seasonal_growth', f.seasonal_growth)) AS x(method, fc)
WHERE f.purpose = 'backtest' AND x.fc IS NOT NULL
GROUP BY x.method;

SELECT * FROM #bt_pooled ORDER BY wape_pct;

/* ---------------------------------------------------------------------
   4. Final forecast: refit on all 24 months, next 6 months, using the
      method in @selected. Band = forecast +/- that method's pooled
      backtest MAE (a rough range, not a statistical interval).
      Selection rule: among methods tested at both origins, the lowest
      pooled WAPE. The final horizon (Jan-Jun) matches the origin-12 test
      window, which is why that origin matters; a method that only wins on
      the Jul-Dec holdout is not chosen.
   --------------------------------------------------------------------- */
SELECT f.horizon, f.target_month,
       @selected AS method,
       CAST(x.fc AS DECIMAL(18,2))                  AS forecast,
       CAST(x.fc - b.mae AS DECIMAL(18,2))          AS low_band,
       CAST(x.fc + b.mae AS DECIMAL(18,2))          AS high_band
FROM #fc f
CROSS APPLY (VALUES ('naive_last',      f.naive_last),
                    ('ma3',             f.ma3),
                    ('ma6',             f.ma6),
                    ('mean_all',        f.mean_all),
                    ('seasonal_naive',  f.seasonal_naive),
                    ('seasonal_growth', f.seasonal_growth)) AS x(method, fc)
JOIN #bt_pooled b ON b.method = x.method
WHERE f.purpose = 'final' AND x.method = @selected
ORDER BY f.horizon;

/* 4b. Same horizon under every method, for comparison ($ millions) */
SELECT f.horizon, f.target_month,
       CAST(f.naive_last      / 1000000.0 AS DECIMAL(8,2)) AS naive_last_m,
       CAST(f.ma3             / 1000000.0 AS DECIMAL(8,2)) AS ma3_m,
       CAST(f.ma6             / 1000000.0 AS DECIMAL(8,2)) AS ma6_m,
       CAST(f.mean_all        / 1000000.0 AS DECIMAL(8,2)) AS mean_all_m,
       CAST(f.seasonal_naive  / 1000000.0 AS DECIMAL(8,2)) AS seasonal_naive_m,
       CAST(f.seasonal_growth / 1000000.0 AS DECIMAL(8,2)) AS seasonal_growth_m
FROM #fc f
WHERE f.purpose = 'final'
ORDER BY f.horizon;