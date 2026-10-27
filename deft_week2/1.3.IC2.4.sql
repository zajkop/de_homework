-- Medallion Architecture
--
-- Build a Bronze-to-Silver-to-Gold pipeline using stage.raw_events and stage.books.
-- Repeated event IDs carry the same business data, each order_line_id has one
-- distinct event, and the books do not change. All payload fields are present and can
-- be cast to the types listed in the starter.
-- In Bronze, keep everything you receive, including repeated deliveries. Append the
-- source rows to bronze.raw_events and bronze.books, preserving all source
-- columns. Give each row a new delivery key and a load_id; do not use the source
-- ingest_id as the Bronze primary key.
-- Build typed Silver tables from Bronze. First deduplicate events by event_id. In
-- silver.customers, keep the latest state for each customer_id, using the greatest
-- occurred_at. In silver.books, keep one row per book_id. In silver.order_lines, keep
-- one valid row per order_line_id, including cancelled lines.
-- A valid line has quantity > 0, unit_price >= 0, a status of completed or cancelled,
-- and customer_id and book_id values that match customers and books in Silver.
-- Free items are allowed. Put invalid order events in silver.rejected_order_lines,
-- keeping one row per event_id with the original payload and a rejection reason.
-- For Gold, join valid completed Silver lines to silver.books and create
-- gold.monthly_genre_sales. Keep one row per UTC month and genre, with columns
-- month_start DATE, genre TEXT and gross_revenue NUMERIC(12,2).
--
-- Check your work: After the first load, Bronze should contain 12 event deliveries
-- and 2 book rows. Silver should have 2 current customers (customer 1: Business;
-- customer 2: Retail), 2 books and 5 valid lines: 4 completed and 1 cancelled. The
-- only rejected event should be line-1006, with the reason quantity_not_positive.
-- Gold should have 4 rows matching the month-genre totals in IC2.1, totaling 125.00.
-- Now append stage.raw_events and stage.books again with a new load_id, then
-- refresh Silver and Gold. Bronze should grow to 24 event deliveries and 4 book rows.
-- Every Silver and Gold table, including the rejected-event table, should keep the
-- same logical rows and values. Show the before-and-after counts and compare the
-- rows to confirm that nothing has changed.

SELECT *
FROM stage.raw_events;
SELECT *
FROM stage.books;

CREATE SCHEMA IF NOT EXISTS bronze;

CREATE TABLE IF NOT EXISTS bronze.raw_events
(
    delivery_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    load_id      BIGINT      NOT NULL,
    ingest_id    BIGINT      NOT NULL,
    event_id     TEXT        NOT NULL,
    entity       TEXT        NOT NULL,
    occurred_at  TIMESTAMPTZ NOT NULL,
    received_at  TIMESTAMPTZ NOT NULL,
    payload      JSONB       NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.books
(
    delivery_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    load_id      BIGINT NOT NULL,
    book_id      BIGINT NOT NULL,
    title        TEXT   NOT NULL,
    author_name  TEXT   NOT NULL,
    genre        TEXT   NOT NULL
);

INSERT INTO bronze.raw_events (load_id, ingest_id, event_id, entity, occurred_at, received_at, payload)
SELECT 1, ingest_id, event_id, entity, occurred_at, received_at, payload
FROM stage.raw_events;

INSERT INTO bronze.books (load_id, book_id, title, author_name, genre)
SELECT 1, book_id, title, author_name, genre
FROM stage.books;

CREATE SCHEMA IF NOT EXISTS silver;

CREATE TABLE silver.customers
(
    customer_id BIGINT PRIMARY KEY,
    email       TEXT        NOT NULL,
    country     TEXT        NOT NULL,
    segment     TEXT        NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL
);

WITH dedupEvents AS (SELECT DISTINCT ON (event_id) occurred_at,
                                                   payload ->> 'customer_id' AS customer_id,
                                                   payload ->> 'email'       AS email,
                                                   payload ->> 'country'     AS country,
                                                   payload ->> 'segment'     AS segment
                     FROM bronze.raw_events
                     WHERE entity = 'customer'),
     latestCustomerVersion AS (SELECT DISTINCT ON (customer_id) *
                               FROM dedupEvents
                               ORDER BY customer_id, occurred_at DESC)
INSERT
INTO silver.customers (customer_id, email, country, segment, occurred_at)
SELECT customer_id::bigint, email, country, segment, occurred_at
FROM latestCustomerVersion;

SELECT *
FROM silver.customers;

CREATE TABLE IF NOT EXISTS silver.books
(
    book_id     BIGINT PRIMARY KEY,
    title       TEXT NOT NULL,
    author_name TEXT NOT NULL,
    genre       TEXT NOT NULL
);

INSERT INTO silver.books (book_id, title, author_name, genre)
SELECT DISTINCT ON (book_id) book_id, title, author_name, genre
FROM bronze.books
ORDER BY book_id, delivery_key;

SELECT *
FROM silver.books;

CREATE TABLE silver.order_lines
(
    order_line_id bigint PRIMARY KEY,
    order_id      bigint         NOT NULL,
    customer_id   bigint         NOT NULL REFERENCES silver.customers (customer_id),
    book_id       bigint         NOT NULL REFERENCES silver.books (book_id),
    ordered_at    timestamptz    NOT NULL,
    status        text           NOT NULL CHECK (status = 'completed' OR status = 'cancelled'),
    quantity      integer        NOT NULL CHECK (quantity > 0),
    unit_price    numeric(10, 2) NOT NULL CHECK (unit_price >= 0)
);

SELECT DISTINCT ON (event_id) *
FROM bronze.raw_events
WHERE entity = 'order_line';

INSERT INTO silver.order_lines (order_line_id, order_id, customer_id, book_id, ordered_at, status, quantity, unit_price)
SELECT order_line_id,
       order_id,
       customer_id,
       book_id,
       ordered_at,
       status,
       quantity,
       unit_price
FROM (SELECT DISTINCT ON (event_id) (payload ->> 'order_line_id')::bigint   AS order_line_id,
                                    (payload ->> 'order_id')::bigint        AS order_id,
                                    (payload ->> 'customer_id')::bigint     AS customer_id,
                                    (payload ->> 'book_id')::bigint         AS book_id,
                                    (payload ->> 'ordered_at')::timestamptz AS ordered_at,
                                    payload ->> 'status'                    AS status,
                                    (payload ->> 'quantity')::integer       AS quantity,
                                    (payload ->> 'unit_price')::numeric     AS unit_price
      FROM bronze.raw_events
      WHERE entity = 'order_line'
      ORDER BY event_id, delivery_key) e
WHERE e.status IN ('completed', 'cancelled')
  AND e.customer_id IN (SELECT customer_id FROM silver.customers)
  AND e.book_id IN (SELECT book_id FROM silver.books)
  AND e.quantity > 0
  AND e.unit_price >= 0;

CREATE TABLE IF NOT EXISTS silver.rejected_order_lines
(
    event_id         text PRIMARY KEY,
    payload          jsonb NOT NULL,
    rejection_reason text  NOT NULL
);

WITH order_events AS (SELECT DISTINCT ON (event_id) event_id,
                                                    payload,
                                                    (payload ->> 'customer_id')::bigint AS customer_id,
                                                    (payload ->> 'book_id')::bigint     AS book_id,
                                                    payload ->> 'status'                AS status,
                                                    (payload ->> 'quantity')::integer   AS quantity,
                                                    (payload ->> 'unit_price')::numeric AS unit_price
                      FROM bronze.raw_events
                      WHERE entity = 'order_line'
                      ORDER BY event_id, delivery_key),
     checked AS (SELECT event_id,
                        payload,
                        CASE
                            WHEN status NOT IN ('completed', 'cancelled') THEN 'invalid_status'
                            WHEN quantity <= 0 THEN 'quantity_not_positive'
                            WHEN unit_price < 0 THEN 'unit_price_negative'
                            WHEN customer_id NOT IN (SELECT customer_id FROM silver.customers) THEN 'unknown_customer'
                            WHEN book_id NOT IN (SELECT book_id FROM silver.books) THEN 'unknown_book'
                            END AS rejection_reason
                 FROM order_events)
INSERT
INTO silver.rejected_order_lines (event_id, payload, rejection_reason)
SELECT event_id, payload, rejection_reason
FROM checked
WHERE rejection_reason IS NOT NULL;

SELECT *
FROM silver.rejected_order_lines;

CREATE SCHEMA gold;

CREATE TABLE gold.monthly_genre_sales
(
    month_start   DATE           NOT NULL,
    genre         TEXT           NOT NULL,
    gross_revenue NUMERIC(12, 2) NOT NULL,
    UNIQUE (month_start, genre)
);

INSERT INTO gold.monthly_genre_sales (month_start, genre, gross_revenue)
SELECT date_trunc('month', ol.ordered_at AT TIME ZONE 'UTC')::date AS month_start,
       b.genre,
       SUM(ol.quantity * ol.unit_price)                          AS gross_revenue
FROM silver.order_lines ol
         JOIN silver.books b ON b.book_id = ol.book_id
WHERE ol.status = 'completed'
GROUP BY month_start, b.genre;


SELECT check_name, actual, expected, actual = expected AS ok
FROM (SELECT 'bronze.raw_events' AS check_name, count(*) AS actual, 12 AS expected FROM bronze.raw_events
      UNION ALL
      SELECT 'bronze.books', count(*), 2 FROM bronze.books
      UNION ALL
      SELECT 'silver.customers', count(*), 2 FROM silver.customers
      UNION ALL
      SELECT 'silver.books', count(*), 2 FROM silver.books
      UNION ALL
      SELECT 'silver.order_lines', count(*), 5 FROM silver.order_lines
      UNION ALL
      SELECT 'silver.order_lines completed', count(*), 4 FROM silver.order_lines WHERE status = 'completed'
      UNION ALL
      SELECT 'silver.order_lines cancelled', count(*), 1 FROM silver.order_lines WHERE status = 'cancelled'
      UNION ALL
      SELECT 'silver.rejected_order_lines', count(*), 1 FROM silver.rejected_order_lines
      UNION ALL
      SELECT 'gold.monthly_genre_sales', count(*), 4 FROM gold.monthly_genre_sales) c;

SELECT customer_id,
       segment,
       segment = CASE customer_id WHEN 1 THEN 'Business' WHEN 2 THEN 'Retail' END AS ok
FROM silver.customers
ORDER BY customer_id;

SELECT event_id,
       rejection_reason,
       event_id = 'line-1006' AND rejection_reason = 'quantity_not_positive' AS ok,
       payload
FROM silver.rejected_order_lines;

WITH expected (month_start, genre, gross_revenue) AS (VALUES (DATE '2026-02-01', 'Fiction', 20.00),
                                                            (DATE '2026-02-01', 'Technology', 30.00),
                                                            (DATE '2026-03-01', 'Fiction', 60.00),
                                                            (DATE '2026-03-01', 'Technology', 15.00))
SELECT month_start,
       genre,
       e.gross_revenue                                      AS expected,
       g.gross_revenue                                      AS actual,
       e.gross_revenue IS NOT DISTINCT FROM g.gross_revenue AS ok
FROM expected e
         FULL JOIN gold.monthly_genre_sales g USING (month_start, genre)
ORDER BY month_start, genre;

SELECT sum(gross_revenue) AS total, sum(gross_revenue) = 125.00 AS ok
FROM gold.monthly_genre_sales;

CREATE SCHEMA IF NOT EXISTS snapshot;

DROP TABLE IF EXISTS snapshot.customers, snapshot.books, snapshot.order_lines,
    snapshot.rejected_order_lines, snapshot.monthly_genre_sales;

CREATE TABLE snapshot.customers AS SELECT * FROM silver.customers;
CREATE TABLE snapshot.books AS SELECT * FROM silver.books;
CREATE TABLE snapshot.order_lines AS SELECT * FROM silver.order_lines;
CREATE TABLE snapshot.rejected_order_lines AS SELECT * FROM silver.rejected_order_lines;
CREATE TABLE snapshot.monthly_genre_sales AS SELECT * FROM gold.monthly_genre_sales;

BEGIN;

INSERT INTO bronze.raw_events (load_id, ingest_id, event_id, entity, occurred_at, received_at, payload)
SELECT 2, ingest_id, event_id, entity, occurred_at, received_at, payload
FROM stage.raw_events;

INSERT INTO bronze.books (load_id, book_id, title, author_name, genre)
SELECT 2, book_id, title, author_name, genre
FROM stage.books;

COMMIT;

BEGIN;

TRUNCATE silver.order_lines, silver.rejected_order_lines, silver.customers, silver.books,
    gold.monthly_genre_sales;

WITH dedupEvents AS (SELECT DISTINCT ON (event_id) occurred_at,
                                                   payload ->> 'customer_id' AS customer_id,
                                                   payload ->> 'email'       AS email,
                                                   payload ->> 'country'     AS country,
                                                   payload ->> 'segment'     AS segment
                     FROM bronze.raw_events
                     WHERE entity = 'customer'),
     latestCustomerVersion AS (SELECT DISTINCT ON (customer_id) *
                               FROM dedupEvents
                               ORDER BY customer_id, occurred_at DESC)
INSERT
INTO silver.customers (customer_id, email, country, segment, occurred_at)
SELECT customer_id::bigint, email, country, segment, occurred_at
FROM latestCustomerVersion;

INSERT INTO silver.books (book_id, title, author_name, genre)
SELECT DISTINCT ON (book_id) book_id, title, author_name, genre
FROM bronze.books
ORDER BY book_id, delivery_key;

INSERT INTO silver.order_lines (order_line_id, order_id, customer_id, book_id, ordered_at, status, quantity, unit_price)
SELECT order_line_id,
       order_id,
       customer_id,
       book_id,
       ordered_at,
       status,
       quantity,
       unit_price
FROM (SELECT DISTINCT ON (event_id) (payload ->> 'order_line_id')::bigint   AS order_line_id,
                                    (payload ->> 'order_id')::bigint        AS order_id,
                                    (payload ->> 'customer_id')::bigint     AS customer_id,
                                    (payload ->> 'book_id')::bigint         AS book_id,
                                    (payload ->> 'ordered_at')::timestamptz AS ordered_at,
                                    payload ->> 'status'                    AS status,
                                    (payload ->> 'quantity')::integer       AS quantity,
                                    (payload ->> 'unit_price')::numeric     AS unit_price
      FROM bronze.raw_events
      WHERE entity = 'order_line'
      ORDER BY event_id, delivery_key) e
WHERE e.status IN ('completed', 'cancelled')
  AND e.customer_id IN (SELECT customer_id FROM silver.customers)
  AND e.book_id IN (SELECT book_id FROM silver.books)
  AND e.quantity > 0
  AND e.unit_price >= 0;

WITH order_events AS (SELECT DISTINCT ON (event_id) event_id,
                                                    payload,
                                                    (payload ->> 'customer_id')::bigint AS customer_id,
                                                    (payload ->> 'book_id')::bigint     AS book_id,
                                                    payload ->> 'status'                AS status,
                                                    (payload ->> 'quantity')::integer   AS quantity,
                                                    (payload ->> 'unit_price')::numeric AS unit_price
                      FROM bronze.raw_events
                      WHERE entity = 'order_line'
                      ORDER BY event_id, delivery_key),
     checked AS (SELECT event_id,
                        payload,
                        CASE
                            WHEN status NOT IN ('completed', 'cancelled') THEN 'invalid_status'
                            WHEN quantity <= 0 THEN 'quantity_not_positive'
                            WHEN unit_price < 0 THEN 'unit_price_negative'
                            WHEN customer_id NOT IN (SELECT customer_id FROM silver.customers) THEN 'unknown_customer'
                            WHEN book_id NOT IN (SELECT book_id FROM silver.books) THEN 'unknown_book'
                            END AS rejection_reason
                 FROM order_events)
INSERT
INTO silver.rejected_order_lines (event_id, payload, rejection_reason)
SELECT event_id, payload, rejection_reason
FROM checked
WHERE rejection_reason IS NOT NULL;

INSERT INTO gold.monthly_genre_sales (month_start, genre, gross_revenue)
SELECT date_trunc('month', ol.ordered_at AT TIME ZONE 'UTC')::date AS month_start,
       b.genre,
       SUM(ol.quantity * ol.unit_price)                          AS gross_revenue
FROM silver.order_lines ol
         JOIN silver.books b ON b.book_id = ol.book_id
WHERE ol.status = 'completed'
GROUP BY month_start, b.genre;

COMMIT;

SELECT 'bronze.raw_events' AS table_name, load_id, count(*) AS row_count
FROM bronze.raw_events
GROUP BY load_id
UNION ALL
SELECT 'bronze.books', load_id, count(*)
FROM bronze.books
GROUP BY load_id
ORDER BY table_name, load_id;

-- table_name,load_id,row_count
-- bronze.books,1,2
-- bronze.books,2,2
-- bronze.raw_events,1,12
-- bronze.raw_events,2,12

SELECT table_name, before, after, only_after, only_before,
       before = after AND only_after = 0 AND only_before = 0 AS ok
FROM (SELECT 'silver.customers' AS table_name,
             (SELECT count(*) FROM snapshot.customers) AS before,
             (SELECT count(*) FROM silver.customers) AS after,
             (SELECT count(*) FROM (SELECT * FROM silver.customers EXCEPT SELECT * FROM snapshot.customers) d) AS only_after,
             (SELECT count(*) FROM (SELECT * FROM snapshot.customers EXCEPT SELECT * FROM silver.customers) d) AS only_before
      UNION ALL
      SELECT 'silver.books',
             (SELECT count(*) FROM snapshot.books),
             (SELECT count(*) FROM silver.books),
             (SELECT count(*) FROM (SELECT * FROM silver.books EXCEPT SELECT * FROM snapshot.books) d),
             (SELECT count(*) FROM (SELECT * FROM snapshot.books EXCEPT SELECT * FROM silver.books) d)
      UNION ALL
      SELECT 'silver.order_lines',
             (SELECT count(*) FROM snapshot.order_lines),
             (SELECT count(*) FROM silver.order_lines),
             (SELECT count(*) FROM (SELECT * FROM silver.order_lines EXCEPT SELECT * FROM snapshot.order_lines) d),
             (SELECT count(*) FROM (SELECT * FROM snapshot.order_lines EXCEPT SELECT * FROM silver.order_lines) d)
      UNION ALL
      SELECT 'silver.rejected_order_lines',
             (SELECT count(*) FROM snapshot.rejected_order_lines),
             (SELECT count(*) FROM silver.rejected_order_lines),
             (SELECT count(*) FROM (SELECT * FROM silver.rejected_order_lines EXCEPT SELECT * FROM snapshot.rejected_order_lines) d),
             (SELECT count(*) FROM (SELECT * FROM snapshot.rejected_order_lines EXCEPT SELECT * FROM silver.rejected_order_lines) d)
      UNION ALL
      SELECT 'gold.monthly_genre_sales',
             (SELECT count(*) FROM snapshot.monthly_genre_sales),
             (SELECT count(*) FROM gold.monthly_genre_sales),
             (SELECT count(*) FROM (SELECT * FROM gold.monthly_genre_sales EXCEPT SELECT * FROM snapshot.monthly_genre_sales) d),
             (SELECT count(*) FROM (SELECT * FROM snapshot.monthly_genre_sales EXCEPT SELECT * FROM gold.monthly_genre_sales) d)) c;

-- table_name,before,after,only_after,only_before,ok
-- silver.customers,2,2,0,0,true
-- silver.books,2,2,0,0,true
-- silver.order_lines,5,5,0,0,true
-- silver.rejected_order_lines,1,1,0,0,true
-- gold.monthly_genre_sales,4,4,0,0,true