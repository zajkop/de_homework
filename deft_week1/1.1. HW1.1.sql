/* Window Function Workshop

Part A -- Cohort retention: A customer joins a cohort in the month of their first paid order. For
each cohort, report its customer count and the percent who made at least one paid purchase in
month 0, 1, 2, 3, 4 and 5. Count a customer only once per month; show zero percent when no
one returns. Handle month offsets across year boundaries.

Part B -- RFM segmentation: Choose and state a fixed analysis date. For each customer with
a paid order, compute recency (days since most recent paid order), frequency (number of paid
orders) and monetary value (paid item revenue). Score each measure with NTILE(5): 5 is
best; smaller recency is better.

Submit: The two SQL queries and results, your analysis date, and one explanation of a
customer segment. Exclude pending, cancelled and refunded orders from both analyses.
 */

-- Part A -- Cohort retention: A customer joins a cohort in the month of their first paid order. For
-- each cohort, report its customer count and the percent who made at least one paid purchase in
-- month 0, 1, 2, 3, 4 and 5. Count a customer only once per month; show zero percent when no
-- one returns. Handle month offsets across year boundaries.

BEGIN;

INSERT INTO customers (id, email, country)
VALUES (101, 'cohort.test101@example.com', 'Poland'),
       (102, 'cohort.test102@example.com', 'Poland'),
       (103, 'cohort.test103@example.com', 'Poland'),
       (104, 'cohort.test104@example.com', 'Poland'),
       (105, 'cohort.test105@example.com', 'Poland'),
       (106, 'cohort.test106@example.com', 'Poland'),
       (107, 'cohort.test107@example.com', 'Poland'),
       (108, 'cohort.test108@example.com', 'Poland');

INSERT INTO orders (id, customer_id, placed_at, status)
VALUES (900001, 101, '2025-11-05 12:00:00+00', 'paid'),
       (900002, 101, '2025-11-20 12:00:00+00', 'paid'),
       (900003, 101, '2025-12-03 12:00:00+00', 'paid'),
       (900004, 101, '2026-01-15 12:00:00+00', 'paid'),
       (900005, 101, '2026-02-10 12:00:00+00', 'cancelled'),
       (900006, 102, '2025-10-28 12:00:00+00', 'pending'),
       (900007, 102, '2025-11-12 12:00:00+00', 'paid'),
       (900008, 102, '2026-02-01 12:00:00+00', 'paid'),
       (900009, 103, '2025-11-25 12:00:00+00', 'paid'),
       (900010, 104, '2025-12-10 12:00:00+00', 'paid'),
       (900011, 104, '2026-01-05 12:00:00+00', 'paid'),
       (900012, 104, '2026-05-20 12:00:00+00', 'paid'),
       (900013, 105, '2025-12-15 12:00:00+00', 'paid'),
       (900014, 105, '2026-01-10 12:00:00+00', 'refunded'),
       (900015, 105, '2026-03-10 12:00:00+00', 'paid'),
       (900016, 106, '2026-01-02 12:00:00+00', 'paid'),
       (900017, 106, '2026-02-02 12:00:00+00', 'paid'),
       (900018, 106, '2026-02-25 12:00:00+00', 'paid'),
       (900019, 107, '2026-01-20 12:00:00+00', 'paid'),
       (900020, 107, '2026-08-01 12:00:00+00', 'paid'),
       (900021, 108, '2026-03-01 12:00:00+00', 'pending');

SELECT customer_id, date_trunc('month', MIN(placed_at))::date AS cohort_month
FROM orders
WHERE status = 'paid'
GROUP BY customer_id;

WITH paidOrders AS (SELECT customer_id,
                           date_trunc('month', placed_at)::date                                       AS order_month,
                           date_trunc('month', MIN(placed_at) OVER (PARTITION BY customer_id))::date AS cohort_month
                    FROM orders
                    WHERE status = 'paid'),
     activity AS (SELECT DISTINCT customer_id,
                                  cohort_month,
                                  (EXTRACT(YEAR FROM order_month) - EXTRACT(YEAR FROM cohort_month)) * 12
                                      + (EXTRACT(MONTH FROM order_month) - EXTRACT(MONTH FROM cohort_month)) AS cohortOffset
                  FROM paidOrders)
SELECT cohort_month,
       COUNT(DISTINCT customer_id)                                                                                 AS customers,
       ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE cohortOffset = 0) / COUNT(DISTINCT customer_id), 1) AS m0,
       ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE cohortOffset = 1) / COUNT(DISTINCT customer_id), 1) AS m1,
       ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE cohortOffset = 2) / COUNT(DISTINCT customer_id), 1) AS m2,
       ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE cohortOffset = 3) / COUNT(DISTINCT customer_id), 1) AS m3,
       ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE cohortOffset = 4) / COUNT(DISTINCT customer_id), 1) AS m4,
       ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE cohortOffset = 5) / COUNT(DISTINCT customer_id), 1) AS m5
FROM activity
GROUP BY cohort_month
ORDER BY cohort_month;

-- cohort_month,customers,m0,m1,m2,m3,m4,m5
-- 2025-10-01,30,100,100,100,100,100,100
-- 2025-11-01,3,100,33.3,33.3,33.3,0,0
-- 2025-12-01,2,100,50,0,50,0,50
-- 2026-01-01,2,100,50,0,0,0,0

ROLLBACK;

-- Part B -- RFM segmentation: Choose and state a fixed analysis date. For each customer with
-- a paid order, compute recency (days since most recent paid order), frequency (number of paid
-- orders) and monetary value (paid item revenue). Score each measure with NTILE(5): 5 is
-- best; smaller recency is better.

WITH rfm AS (SELECT o.customer_id,
                    DATE '2026-10-13' - MAX(o.placed_at)::date    AS recency,
                    COUNT(DISTINCT o.id)                          AS frequency,
                    COALESCE(SUM(oi.quantity * oi.price_each), 0) AS monetary_value
             FROM orders o
                      LEFT JOIN order_items oi ON o.id = oi.order_id
             WHERE o.status = 'paid'
             GROUP BY o.customer_id)
SELECT customer_id,
       recency,
       frequency,
       monetary_value,
       NTILE(5) OVER (ORDER BY recency)        AS recency_score,
       NTILE(5) OVER (ORDER BY frequency)      AS frequency_score,
       NTILE(5) OVER (ORDER BY monetary_value) AS monetary_value_score
FROM rfm;

-- customer_id,recency,frequency,monetary_value,recency_score,frequency_score,monetary_value_score
-- 19,1,291,63.5,1,1,1
-- 22,1,318,112.49,1,1,3
-- 30,1,322,0,1,2,1
-- 29,1,331,42.5,1,2,1
-- 25,1,334,33.3,1,3,1
-- 10,1,362,141.74,1,5,4
-- 8,1,376,267.13,2,5,5
-- 3,2,323,477.08,2,2,5
-- 14,2,324,105.63,2,2,3
-- 27,2,324,117.9,2,2,3
-- 20,2,353,94.9,2,5,2
-- 13,2,334,146.3,2,3,4
-- 12,2,339,96.15,3,3,3
-- 21,2,341,173.49,3,4,5
-- 5,2,348,151.99,3,4,4
-- 26,3,354,73,3,5,2
-- 9,3,318,136.9,3,1,4
-- 11,3,338,156.44,3,3,4
-- 23,3,340,65.9,4,3,2
-- 17,3,320,87.39,4,1,2
-- 4,3,345,234.96,4,4,5
-- 15,3,352,119.8,4,5,3
-- 6,3,350,112.08,4,4,3
-- 1,3,351,442.76,4,4,5
-- 18,3,305,71.8,5,1,2
-- 7,3,312,168.24,5,1,4
-- 16,3,331,89.74,5,2,2
-- 28,3,332,0,5,3,1
-- 2,4,351,184.68,5,5,5
-- 24,5,348,57.6,5,4,1
--