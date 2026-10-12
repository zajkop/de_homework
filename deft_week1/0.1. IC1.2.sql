/* Joins Refresher: Anti-Join Pattern
Task: Find authors who have no books. Return author_id and name, ordered by author ID.
Write three equivalent versions: NOT EXISTS, LEFT JOIN ... IS NULL and EXCEPT.
Submit: The three queries and matching results, plus each query's EXPLAIN (ANALYZE,
BUFFERS) plan. State which ran fastest on your dataset; explain the plan rather than assuming
one method is always fastest.
*/

-- NOT EXISTS

EXPLAIN ANALYZE SELECT a.id, a.name
FROM authors a
WHERE NOT EXISTS (SELECT 1 FROM books WHERE books.author_id = a.id)
ORDER BY a.id;
-- id,name
-- 11,Clara Rossi
-- QUERY PLAN
-- Sort  (cost=62.22..63.12 rows=360 width=40) (actual time=0.059..0.060 rows=1 loops=1)
--   Sort Key: a.id
--   Sort Method: quicksort  Memory: 25kB
--   ->  Hash Right Anti Join  (cost=26.20..46.93 rows=360 width=40) (actual time=0.050..0.053 rows=1 loops=1)
--         Hash Cond: (books.author_id = a.id)
--         ->  Seq Scan on books  (cost=0.00..15.90 rows=590 width=8) (actual time=0.003..0.005 rows=22 loops=1)
--         ->  Hash  (cost=17.20..17.20 rows=720 width=40) (actual time=0.021..0.021 rows=11 loops=1)
--               Buckets: 1024  Batches: 1  Memory Usage: 9kB
--               ->  Seq Scan on authors a  (cost=0.00..17.20 rows=720 width=40) (actual time=0.013..0.015 rows=11 loops=1)
-- Planning Time: 0.129 ms

-- LEFT JOIN ... IS NULL
EXPLAIN ANALYZE SELECT a.id, a.name
FROM authors a
         LEFT JOIN books b ON a.id = b.author_id
WHERE b.author_id IS NULL
ORDER BY a.id;
-- id,name
-- 11,Clara Rossi
-- QUERY PLAN
-- Sort  (cost=62.22..63.12 rows=360 width=40) (actual time=0.048..0.049 rows=1 loops=1)
--   Sort Key: a.id
--   Sort Method: quicksort  Memory: 25kB
--   ->  Hash Right Anti Join  (cost=26.20..46.93 rows=360 width=40) (actual time=0.040..0.042 rows=1 loops=1)
--         Hash Cond: (b.author_id = a.id)
--         ->  Seq Scan on books b  (cost=0.00..15.90 rows=590 width=8) (actual time=0.003..0.004 rows=22 loops=1)
--         ->  Hash  (cost=17.20..17.20 rows=720 width=40) (actual time=0.028..0.028 rows=11 loops=1)
--               Buckets: 1024  Batches: 1  Memory Usage: 9kB
--               ->  Seq Scan on authors a  (cost=0.00..17.20 rows=720 width=40) (actual time=0.016..0.024 rows=11 loops=1)
-- Planning Time: 0.089 ms

-- EXCEPT
EXPLAIN ANALYZE SELECT a.id, a.name FROM authors a
EXCEPT
SELECT b.author_id, a.name FROM books b JOIN authors a ON b.author_id = a.id
ORDER BY id;
-- id,name
-- 11,Clara Rossi
-- Sort  (cost=121.23..123.03 rows=720 width=44) (actual time=0.052..0.054 rows=1 loops=1)
-- "  Sort Key: ""*SELECT* 1"".id"
--   Sort Method: quicksort  Memory: 25kB
--   ->  HashSetOp Except  (cost=0.00..87.06 rows=720 width=44) (actual time=0.046..0.050 rows=1 loops=1)
--         ->  Append  (cost=0.00..80.51 rows=1310 width=44) (actual time=0.012..0.037 rows=33 loops=1)
-- "              ->  Subquery Scan on ""*SELECT* 1""  (cost=0.00..24.40 rows=720 width=44) (actual time=0.011..0.014 rows=11 loops=1)"
--                     ->  Seq Scan on authors a  (cost=0.00..17.20 rows=720 width=40) (actual time=0.011..0.012 rows=11 loops=1)
-- "              ->  Subquery Scan on ""*SELECT* 2""  (cost=26.20..49.56 rows=590 width=44) (actual time=0.012..0.020 rows=22 loops=1)"
--                     ->  Hash Join  (cost=26.20..43.66 rows=590 width=40) (actual time=0.011..0.018 rows=22 loops=1)
--                           Hash Cond: (b.author_id = a_1.id)
--                           ->  Seq Scan on books b  (cost=0.00..15.90 rows=590 width=8) (actual time=0.003..0.004 rows=22 loops=1)
--                           ->  Hash  (cost=17.20..17.20 rows=720 width=40) (actual time=0.005..0.005 rows=11 loops=1)
--                                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
--                                 ->  Seq Scan on authors a_1  (cost=0.00..17.20 rows=720 width=40) (actual time=0.001..0.002 rows=11 loops=1)
-- Planning Time: 0.110 ms


-- Explanation
-- LEFT JOIN ... IS NULL was the fastest method.
-- However, the difference compared to the other two methods was very small.
-- The performance differences between all three methods were negligible, most likely because the dataset is relatively small.
-- With only 11 authors and 22 books returned by the table scans, all three queries could be executed very quickly.
-- Therefore, it is difficult to justify choosing one method over another based on execution time alone.
-- Both NOT EXISTS and LEFT JOIN ... IS NULL were optimized into the same Hash Right Anti Join operation.
-- This shows that PostgreSQL recognized their equivalent anti-join semantics and generated essentially the same execution plan for both queries.
-- The anti-join efficiently identifies authors who have no matching records in the books table.
-- The EXCEPT method produced the most complex and verbose execution plan.
-- It used an Append operation to combine the results of both subqueries, a Hash Join to identify authors with books, and a HashSetOp Except operation to remove those authors from the complete set of authors.
-- Although the plan contains more steps, its execution time was still comparable to the other methods.
-- Overall, all three queries returned the same result, but PostgreSQL executed them differently.
-- For this dataset, LEFT JOIN ... IS NULL had the lowest measured execution time, followed by EXCEPT and NOT EXISTS.
-- However, these differences are too small to establish a meaningful performance advantage.
-- In practice, NOT EXISTS is often a clear and readable choice when checking for the absence of related records, while the actual execution plan and performance measurements should guide optimization decisions.
