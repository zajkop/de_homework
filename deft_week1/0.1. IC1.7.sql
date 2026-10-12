/* EXPLAIN: Sequential Scan vs Index Scan
Task: In a disposable test database, load at least 100,000 orders, including 50 or more for
customer 1. For a no-index baseline, temporarily drop idx_orders_customer and
idx_orders_placed. Run ANALYZE orders and capture the plan for:
SELECT id, placed_at, status
FROM orders
WHERE customer_id = 1
ORDER BY placed_at DESC
LIMIT 20;
Then: Create an index on (customer_id, placed_at DESC), run ANALYZE orders and
capture the same EXPLAIN (ANALYZE, BUFFERS) plan again. Compare scan, sort, buffer
reads and execution time. Explain why an index scan is not guaranteed, and restore indexes
needed by later work.
*/

INSERT INTO orders (id, customer_id, placed_at, status)
SELECT g.id,
       2 + floor(random() * 29)::int,
       TIMESTAMPTZ '2024-01-01 00:00:00+00' + random() * INTERVAL '1000 days',
       (ARRAY ['pending', 'paid', 'cancelled', 'refunded'])[1 + floor(random() * 4)::int]
FROM generate_series(101, 100100) AS g(id);

INSERT INTO orders (id, customer_id, placed_at, status)
SELECT g.id,
       1,
       TIMESTAMPTZ '2024-01-01 00:00:00+00' + random() * INTERVAL '1000 days',
       (ARRAY ['pending', 'paid', 'cancelled', 'refunded'])[1 + floor(random() * 4)::int]
FROM generate_series(100101, 100160) AS g(id);

DROP INDEX IF EXISTS idx_orders_customer;
DROP INDEX IF EXISTS idx_orders_placed;

ANALYZE orders;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, placed_at, status
FROM orders
WHERE customer_id = 1
ORDER BY placed_at DESC
LIMIT 20;
-- QUERY PLAN
-- Limit  (cost=2041.86..2041.91 rows=20 width=24) (actual time=8.830..8.832 rows=20 loops=1)
--   Buffers: shared hit=788
--   ->  Sort  (cost=2041.86..2042.04 rows=70 width=24) (actual time=8.827..8.828 rows=20 loops=1)
--         Sort Key: placed_at DESC
--         Sort Method: top-N heapsort  Memory: 27kB
--         Buffers: shared hit=788
--         ->  Seq Scan on orders  (cost=0.00..2040.00 rows=70 width=24) (actual time=0.048..8.701 rows=68 loops=1)
--               Filter: (customer_id = 1)
--               Rows Removed by Filter: 100092
--               Buffers: shared hit=788
-- Planning:
--   Buffers: shared hit=12
-- Planning Time: 1.269 ms
-- Execution Time: 8.900 ms


CREATE INDEX idx_orders_customer_placed ON orders (customer_id, placed_at DESC);

ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id, placed_at, status
FROM orders
WHERE customer_id = 1
ORDER BY placed_at DESC
LIMIT 20;
-- QUERY PLAN
-- Limit  (cost=0.42..79.45 rows=20 width=24) (actual time=0.070..0.084 rows=20 loops=1)
--   Buffers: shared hit=10 read=3
--   ->  Index Scan using idx_orders_customer_placed on orders  (cost=0.42..249.38 rows=63 width=24) (actual time=0.068..0.080 rows=20 loops=1)
--         Index Cond: (customer_id = 1)
--         Buffers: shared hit=10 read=3
-- Planning:
--   Buffers: shared hit=16 read=1
-- Planning Time: 0.342 ms
-- Execution Time: 0.105 ms

CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_orders_placed ON orders (placed_at);

DROP INDEX IF EXISTS idx_orders_customer_placed;

-- =====================================================================
-- Comparison
-- =====================================================================
--                 | no index                                   | index (customer_id, placed_at DESC)
-- Scan            | Seq Scan on orders - reads every row,      | Index Scan using idx_orders_customer_placed,
--                 | Rows Removed by Filter: 100092 (68 kept)   | Index Cond: (customer_id = 1), stops after 20 rows
-- Sort            | Sort, top-N heapsort                       | none - the index already returns rows in placed_at DESC order
-- Buffers         | shared hit=788                             | shared hit=10 read=3
-- Cost (estimate) | 2041.91                                    | 79.45
-- Execution Time  | 8.900 ms                                   | 0.105 ms

-- =====================================================================
-- Explanation: why an index scan is not guaranteed
-- =====================================================================
-- PostgreSQL uses a cost-based planner so the planner estimates the cost of every option and picks the cheapest one, not "the index, because it exists".
-- - Selectivity: if the filter matches a large share of rows (e.g. customer_id > 1), a sequential read of the
--   whole table is cheaper than a random heap access for each index entry.
-- - Statistics: estimates come from ANALYZE. Without ANALYZE after loading 100,000 rows the planner
--   can work with wrong row counts and choose a bad plan - that is why the task runs ANALYZE.
-- - Table size: a small table (e.g. books with 22 rows in IC1.2) fits in a few pages, so Seq Scan wins.
-- - Index usability: a filter without the leading column (only placed_at for an index on (customer_id, placed_at))
--   or a type mismatch can make the index unusable.


DELETE FROM orders WHERE id > 100;
