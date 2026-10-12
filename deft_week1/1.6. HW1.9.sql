/* pg_stat_statements Top 10

Task: On a development database, enable pg_stat_statements if permissions and
configuration allow it (preloading and a restart may be needed). Run a representative workload;
list the 10 normalized queries with the highest total_exec_time. Include calls, mean
execution time and buffer reads/hits.
Submit: Choose three costly queries, improve them with an index or SQL rewrite, then
compare results and before/after EXPLAIN (ANALYZE, BUFFERS) plans and timings. If the
extension is unavailable, choose three representative queries, perform the same plan
comparison, and state the limitation.

 */

ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
-- docker restart clean-pg
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SHOW shared_preload_libraries;

SELECT *
FROM orders
WHERE id = 500;

SELECT *
FROM customers
WHERE id = 1;

SELECT *
FROM orders
WHERE customer_id = 1
ORDER BY placed_at DESC
LIMIT 10;

SELECT count(*)
FROM orders
WHERE customer_id = 1
  AND status = 'paid';

SELECT count(*)
FROM orders
WHERE placed_at::date = current_date - 5;

SELECT *
FROM orders
WHERE status IN ('cancelled', 'refunded');

SELECT c.email, (SELECT count(*) FROM orders o WHERE o.customer_id = c.id) AS orders_cnt
FROM customers c;

SELECT date_trunc('day', placed_at) AS day, count(*)
FROM orders
WHERE placed_at >= now() - interval '30 days'
GROUP BY 1
ORDER BY 1;

SELECT b.title, b.price
FROM books b
         JOIN authors a ON a.id = b.author_id
WHERE a.id = 1;

SELECT b.title, sum(oi.quantity) AS sold
FROM order_items oi
         JOIN books b ON b.id = oi.book_id
GROUP BY b.title
ORDER BY sold DESC
LIMIT 5;

SELECT o.id, o.status, b.title, oi.quantity
FROM orders o
         JOIN order_items oi ON oi.order_id = o.id
         JOIN books b ON b.id = oi.book_id
WHERE o.id = 1;


SELECT query,
       calls,
       round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2)  AS mean_ms,
       shared_blks_hit,
       shared_blks_read
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

--
-- query,calls,total_ms,mean_ms,shared_blks_hit,shared_blks_read
-- "SELECT c.email, (SELECT count(*) FROM orders o WHERE o.customer_id = c.id) AS orders_cnt FROM customers c",5,428.67,85.73,110555,0
-- SELECT count(*) FROM orders WHERE placed_at::date = current_date - $1,5,69.18,13.84,3685,0
-- "SELECT * FROM orders WHERE status IN ($1, $2)",5,47.07,9.41,3685,0
-- SELECT count(*) FROM orders WHERE customer_id = $1 AND status = $2,5,43.71,8.74,3258,427
-- "SELECT date_trunc($1, placed_at) AS day, count(*) FROM orders WHERE placed_at >= now() - interval $2 GROUP BY 1 ORDER BY 1",5,12.95,2.59,147,31
-- SELECT * FROM orders WHERE customer_id = $1 ORDER BY placed_at DESC LIMIT $2,5,9.76,1.95,1702,313
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements,1,16.76,16.76,3348,111
--

-- TOP 3 costly:
-- 1) SELECT c.email, (SELECT count(*) FROM orders o WHERE o.customer_id = c.id) AS orders_cnt FROM customers c
-- total_ms: 428.67, mean_ms: 85.73, shared_blks_hit: 110555, shared_blks_read: 0

-- Before fix analysis
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.email, (SELECT count(*) FROM orders o WHERE o.customer_id = c.id) AS orders_cnt
FROM customers c;
-- Seq Scan on customers c  (cost=0.00..1497469.38 rows=750 width=40) (actual time=36.751..131.849 rows=30 loops=1)
--   Buffers: shared hit=22111
--   SubPlan 1
--     ->  Aggregate  (cost=1996.59..1996.60 rows=1 width=8) (actual time=3.502..3.502 rows=1 loops=30)
--           Buffers: shared hit=22110
--           ->  Seq Scan on orders o  (cost=0.00..1988.25 rows=3337 width=0) (actual time=0.003..3.388 rows=3337 loops=30)
--                 Filter: (customer_id = c.id)
--                 Rows Removed by Filter: 96763
--                 Buffers: shared hit=22110
-- Planning Time: 0.449 ms
-- JIT:
--   Functions: 8
-- "  Options: Inlining true, Optimization true, Expressions true, Deforming true"
-- "  Timing: Generation 2.121 ms (Deform 0.513 ms), Inlining 7.721 ms, Optimization 8.838 ms, Emission 10.083 ms, Total 28.763 ms"
-- Execution Time: 134.228 ms


-- After fix analysis
EXPLAIN (ANALYZE, BUFFERS)
WITH customerOrders AS (SELECT o.customer_id, COUNT(o.customer_id) ccount FROM orders o GROUP BY o.customer_id)
SELECT c.email, co.customer_id, co.ccount
FROM customerOrders co
         LEFT JOIN customers c ON co.customer_id = c.id;
-- Hash Right Join  (cost=2239.18..2258.65 rows=30 width=48) (actual time=29.214..29.228 rows=30 loops=1)
--   Hash Cond: (c.id = o.customer_id)
--   Buffers: shared hit=738
--   ->  Seq Scan on customers c  (cost=0.00..17.50 rows=750 width=40) (actual time=0.021..0.026 rows=30 loops=1)
--         Buffers: shared hit=1
--   ->  Hash  (cost=2238.80..2238.80 rows=30 width=16) (actual time=29.152..29.152 rows=30 loops=1)
--         Buckets: 1024  Batches: 1  Memory Usage: 10kB
--         Buffers: shared hit=737
--         ->  HashAggregate  (cost=2238.50..2238.80 rows=30 width=16) (actual time=29.128..29.136 rows=30 loops=1)
--               Group Key: o.customer_id
--               Batches: 1  Memory Usage: 24kB
--               Buffers: shared hit=737
--               ->  Seq Scan on orders o  (cost=0.00..1738.00 rows=100100 width=8) (actual time=0.062..10.113 rows=100100 loops=1)
--                     Buffers: shared hit=737
-- Planning:
--   Buffers: shared hit=8 read=1
-- Planning Time: 2.568 ms
-- Execution Time: 29.521 ms


-- Comparison: execution_time: 134.228 vs 29.521, shared hit=22111 vs 738
CREATE INDEX orders_placed_at_idx ON orders (placed_at);
ANALYZE orders;

-- 2) SELECT count(*) FROM orders WHERE placed_at::date = current_date - $1
-- total_ms: 69.18, mean_ms: 13.84, shared_blks_hit: 3685, shared_blks_read: 0

-- Before fix analysis
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM orders
WHERE placed_at::date = current_date - 5;
-- Aggregate  (cost=2740.25..2740.26 rows=1 width=8) (actual time=25.425..25.426 rows=1 loops=1)
--   Buffers: shared hit=737
--   ->  Seq Scan on orders  (cost=0.00..2739.00 rows=500 width=0) (actual time=0.100..25.383 rows=283 loops=1)
--         Filter: ((placed_at)::date = (CURRENT_DATE - 5))
--         Rows Removed by Filter: 99817
--         Buffers: shared hit=737
-- Planning:
--   Buffers: shared hit=5
-- Planning Time: 1.387 ms
-- Execution Time: 25.550 ms

CREATE INDEX orders_placed_at_idx ON orders (placed_at);
ANALYZE orders;

-- After fix analysis
-- current date 2026-10-10, current-date - 5 = 2026-10-5, placed_at = 2026-10-05 14:23:11, placed_at::date = 2026-10-05,
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*)
FROM orders
WHERE placed_at >= current_date - 5
  AND placed_at < current_date - 4;
-- Aggregate  (cost=15.35..15.36 rows=1 width=8) (actual time=0.213..0.214 rows=1 loops=1)
--   Buffers: shared hit=7
--   ->  Index Only Scan using idx_orders_placed on orders  (cost=0.30..14.56 rows=313 width=0) (actual time=0.167..0.193 rows=283 loops=1)
--         Index Cond: ((placed_at >= (CURRENT_DATE - 5)) AND (placed_at < (CURRENT_DATE - 4)))
--         Heap Fetches: 0
--         Buffers: shared hit=7
-- Planning:
--   Buffers: shared hit=17 read=1 dirtied=1
-- Planning Time: 2.191 ms
-- Execution Time: 0.351 ms
--

-- Comparison: execution_time: 25.550 vs 0.351, shared hit=737 vs 7

DROP INDEX IF EXISTS orders_placed_at_idx;
ANALYZE orders;


-- 3) "SELECT * FROM orders WHERE status IN ($1, $2)"
-- total_ms: 47.07, mean_ms: 9.41, shared_blks_hit: 3685, shared_blks_read: 0

-- Before fix analysis
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE status IN ('cancelled', 'refunded');
-- Seq Scan on orders  (cost=0.00..1988.25 rows=7 width=31) (actual time=0.143..23.334 rows=14 loops=1)
-- "  Filter: (status = ANY ('{cancelled,refunded}'::text[]))"
--   Rows Removed by Filter: 100086
--   Buffers: shared hit=737
-- Planning Time: 1.018 ms
-- Execution Time: 23.437 ms

CREATE INDEX order_status_idx ON orders (status);
ANALYZE orders;

-- After fix analysis
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE status IN ('cancelled', 'refunded');
-- Index Scan using order_status_idx on orders  (cost=0.29..28.94 rows=13 width=31) (actual time=0.120..0.169 rows=14 loops=1)
-- "  Index Cond: (status = ANY ('{cancelled,refunded}'::text[]))"
--   Buffers: shared hit=2 read=3
-- Planning:
--   Buffers: shared hit=14 read=1
-- Planning Time: 0.868 ms
-- Execution Time: 0.216 ms

-- Comparison: execution_time: 23.437 vs 0.216, shared hit=737 vs 2

DROP INDEX IF EXISTS order_status_idx;
ANALYZE orders;




