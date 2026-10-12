/* Partial vs Full Index Test

Task: Use at least 100,000 orders, with paid orders making up a minority of rows. Benchmark
the same query filtered by customer_id = 1 AND status = 'paid' under three setups:
(1) no candidate index, (2) a full index on (customer_id), and (3) a partial index on
(customer_id) WHERE status = 'paid'. Keep the data unchanged and test only one
candidate index at a time.
Submit: Query plans, buffer use and execution times from EXPLAIN (ANALYZE, BUFFERS);
index sizes from pg_relation_size; and repeatable timing for inserting and updating rows
under each setup. Explain read speed, index size and write overhead, even if PostgreSQL
chooses not to use an index.
 */

INSERT INTO orders (id, customer_id, placed_at, status)
SELECT (SELECT max(id) FROM orders) + n,
       random(1, 30),
       NOW() - random() * INTERVAL '365 days',
       CASE WHEN random() < 0.1 THEN 'paid' ELSE 'pending' END
FROM generate_series(1, 100000) AS n;

VACUUM ANALYZE orders;

-- 1) No index
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 1 AND status = 'paid';
-- Seq Scan on orders  (cost=0.00..2238.50 rows=327 width=31) (actual time=0.001..2.692 rows=351 loops=1)
--   Filter: ((customer_id = 1) AND (status = 'paid'::text))
--   Rows Removed by Filter: 99749
--   Buffers: shared hit=737
-- Planning Time: 0.010 ms
-- Execution Time: 2.703 ms

BEGIN;
SELECT setseed(0.5);
EXPLAIN (ANALYZE, BUFFERS) INSERT INTO orders (id, customer_id, placed_at, status)
SELECT (SELECT max(id) FROM orders) + n, random(1, 30), NOW() - random() * INTERVAL '365 days',
       CASE WHEN random() < 0.1 THEN 'paid' ELSE 'pending' END
FROM generate_series(1, 10000) AS n;
ROLLBACK;
VACUUM orders;
-- Execution Time: 35.3 ms, Buffers: shared hit=50317

BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE orders SET status = 'paid' WHERE id <= 10000;
ROLLBACK;
VACUUM orders;
-- Execution Time: 21.2 ms, Buffers: shared hit=90389

BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE orders SET status = 'cancelled' WHERE id <= 10000;
ROLLBACK;
VACUUM orders;
-- Execution Time: 21.4 ms, Buffers: shared hit=90409

-- 2) full index on (customer_id)
CREATE INDEX idx_orders_customer ON orders (customer_id);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 1 AND status = 'paid';
-- Bitmap Heap Scan on orders  (cost=37.35..824.30 rows=334 width=31) (actual time=0.096..0.474 rows=351 loops=1)
--   Recheck Cond: (customer_id = 1)
--   Filter: (status = 'paid'::text)
--   Rows Removed by Filter: 2980
--   Heap Blocks: exact=730
--   Buffers: shared hit=734
--   ->  Bitmap Index Scan on idx_orders_customer  (cost=0.00..37.27 rows=3330 width=0) (actual time=0.054..0.054 rows=3331 loops=1)
--         Index Cond: (customer_id = 1)
--         Buffers: shared hit=4
-- Planning Time: 0.008 ms
-- Execution Time: 0.485 ms

SELECT pg_relation_size('idx_orders_customer'), pg_size_pretty(pg_relation_size('idx_orders_customer'));
-- 720896,704 kB

BEGIN;
SELECT setseed(0.5);
EXPLAIN (ANALYZE, BUFFERS) INSERT INTO orders (id, customer_id, placed_at, status)
SELECT (SELECT max(id) FROM orders) + n, random(1, 30), NOW() - random() * INTERVAL '365 days',
       CASE WHEN random() < 0.1 THEN 'paid' ELSE 'pending' END
FROM generate_series(1, 10000) AS n;
ROLLBACK;
VACUUM orders;
-- Execution Time: 40.2 ms, Buffers: shared hit=70352

BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE orders SET status = 'paid' WHERE id <= 10000;
ROLLBACK;
VACUUM orders;
-- Execution Time: 29.4 ms, Buffers: shared hit=110498

BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE orders SET status = 'cancelled' WHERE id <= 10000;
ROLLBACK;
VACUUM orders;
-- Execution Time: 29.9 ms, Buffers: shared hit=110518

DROP INDEX IF EXISTS idx_orders_customer;

-- 3) a partial index on (customer_id) WHERE status = 'paid'
CREATE INDEX idx_orders_customer_paid ON orders (customer_id) WHERE status = 'paid';
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM orders WHERE customer_id = 1 AND status = 'paid';
-- Bitmap Heap Scan on orders  (cost=6.91..609.30 rows=339 width=31) (actual time=0.024..0.115 rows=351 loops=1)
--   Recheck Cond: ((customer_id = 1) AND (status = 'paid'::text))
--   Heap Blocks: exact=282
--   Buffers: shared hit=284
--   ->  Bitmap Index Scan on idx_orders_customer_paid  (cost=0.00..6.83 rows=339 width=0) (actual time=0.010..0.010 rows=351 loops=1)
--         Index Cond: (customer_id = 1)
--         Buffers: shared hit=2
-- Planning Time: 0.020 ms
-- Execution Time: 0.127 ms

SELECT pg_relation_size('idx_orders_customer_paid'), pg_size_pretty(pg_relation_size('idx_orders_customer_paid'));
-- 90112,88 kB

BEGIN;
SELECT setseed(0.5);
EXPLAIN (ANALYZE, BUFFERS) INSERT INTO orders (id, customer_id, placed_at, status)
SELECT (SELECT max(id) FROM orders) + n, random(1, 30), NOW() - random() * INTERVAL '365 days',
       CASE WHEN random() < 0.1 THEN 'paid' ELSE 'pending' END
FROM generate_series(1, 10000) AS n;
ROLLBACK;
VACUUM orders;
-- Execution Time: 36.1 ms, Buffers: shared hit=52301

BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE orders SET status = 'paid' WHERE id <= 10000;
ROLLBACK;
VACUUM orders;
-- Execution time: 28.6 ms, Buffers: shared hit=110437

BEGIN;
EXPLAIN (ANALYZE, BUFFERS) UPDATE orders SET status = 'cancelled' WHERE id <= 10000;
ROLLBACK;
VACUUM orders;
-- Execution Time: 22.6 ms, Buffers: shared hit=90409

DROP INDEX IF EXISTS idx_orders_customer_paid;
ANALYZE orders;

-- Explanation
-- Read without an index the whole table is read (737 pages) and 99749 rows are filtered out.
-- The full index finds 3331 rows of customer 1, but they are spread over 730 of 737 pages, so buffers are almost the same as Seq Scan.
-- It is faster only because 3331 rows are checked instead of 100k, and 2980 of them are still removed by the status filter.
-- The partial index holds only paid rows, so it returns exactly 351 rows from 282 pages (~30x faster than Seq Scan, ~4.5x faster than the full index).
-- Size full index 704 kB (100k entries), partial 88 kB (~10k paid rows).
-- Writes full index adds an entry for every inserted/updated row (+~20k buffers, +5 ms insert, +8.5 ms update).
-- Partial index adds an entry only when the new row is paid: insert with 10% paid is almost free:
-- update to cancelled costs nothing, update to paid costs the same as the full index.