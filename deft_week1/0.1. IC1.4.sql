/** Window Frames: Running Totals and Trailing Averages
Task: Make a daily revenue report for September 1-30, 2026 (UTC). Generate all 30 dates
first, then left join paid-order revenue so dates with no sales have revenue 0. Compute
cumulative revenue and the average daily revenue over the current day plus the previous six
days.
Submit: day, daily_revenue, running_revenue, avg_7d. Use explicit ROWS frames.
Verify zero-sale dates are present and explain why the last seven orders would not equal
seven calendar days.
*/


WITH dailyRevenue AS (SELECT EXTRACT(DAY FROM sep.date) AS                 day,
                             COALESCE(SUM(oi.quantity * oi.price_each), 0) revenue
                      FROM (SELECT generate_series('2026-09-01'::date, '2026-10-01'::date,
                                                   '1 day'::interval)::date AS date) sep
                               LEFT JOIN orders o
                                         ON sep.date = (o.placed_at AT TIME ZONE 'UTC')::date AND o.status = 'paid'
                               LEFT JOIN order_items oi ON oi.order_id = o.id
                      GROUP BY day
                      ORDER BY day)
SELECT day,
       revenue daily_revenue,
       SUM(revenue) OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) running_revenue,
       ROUND(AVG(revenue) OVER (ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) avg_7d
FROM dailyRevenue;

-- day,daily_revenue,running_revenue,avg_7d
-- 1,85.99,85.99,85.99
-- 2,52.49,138.48,69.24
-- 3,25,163.48,54.49
-- 4,84.98,248.46,62.12
-- 5,81.4,329.86,65.97
-- 6,39.9,369.76,61.63
-- 7,51.5,421.26,60.18
-- 8,22,443.26,51.04
-- 9,34.9,478.16,48.53
-- 10,42.5,520.66,51.03
-- 11,69.75,590.41,48.85
-- 12,28.8,619.21,41.34
-- 13,0,619.21,35.64
-- 14,111.09,730.3,44.15
-- 15,33.3,763.6,45.76
-- 16,49.99,813.59,47.92
-- 17,43,856.59,47.99
-- 18,82.5,939.09,49.81
-- 19,70.9,1009.99,55.83
-- 20,19.99,1029.98,58.68
-- 21,49.98,1079.96,49.95
-- 22,0,1079.96,45.19
-- 23,56.4,1136.36,46.11
-- 24,31,1167.36,44.4
-- 25,110,1277.36,48.32
-- 26,28.8,1306.16,42.31
-- 27,81.25,1387.41,51.06
-- 28,41.2,1428.61,49.81
-- 29,47,1475.61,56.52
-- 30,39.9,1515.51,54.16

-- Explanation
-- There is 13th day with 0 revenue
-- "explain why the last seven orders would not equal seven calendar days." - might be multiple orders by day then 7 orders = 1 calendar day
