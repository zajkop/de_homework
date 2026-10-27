-- Star Schema
--
-- Use the clean data in stage.star_customers, stage.books and
-- stage.star_order_lines to build star.dim_customer, star.dim_book, star.dim_date
-- and star.fact_order_line. Give the dimensions surrogate keys and unique natural
-- keys, and link the fact table to them with foreign keys. Load the supplied customer
-- and book attributes, keeping author and genre in dim_book. Include one date per
-- distinct UTC order date. Each fact row should represent one order_line_id and
-- contain order_id, quantity, unit_price and line revenue as NUMERIC(12,2). Query
-- revenue by UTC month and genre.
-- Check your work: Expect 2 customers, 2 books, 3 dates and 4 fact rows, with total
-- revenue of 125.00. February 2026 should give Technology 30.00 and Fiction 20.00;
-- March, Technology 15.00 and Fiction 60.00. Run the load again: row counts, keys
-- and totals should stay the same.

CREATE SCHEMA IF NOT EXISTS star;
CREATE TABLE IF NOT EXISTS star.dim_customer(
    customer_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id BIGINT UNIQUE NOT NULL,
    email        text NOT NULL,
    country      text NOT NULL,
    segment      text NOT NULL
);
CREATE TABLE IF NOT EXISTS star.dim_book(
    book_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_id BIGINT UNIQUE NOT NULL,
    title        text NOT NULL,
    author_name  text NOT NULL,
    genre        text NOT NULL
);
CREATE TABLE IF NOT EXISTS star.dim_date(
    date_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_date DATE UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS star.fact_order_line(
    order_line_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_line_id BIGINT UNIQUE NOT NULL,
    order_id BIGINT NOT NULL,
    book_key BIGINT REFERENCES star.dim_book(book_key),
    customer_key BIGINT REFERENCES star.dim_customer(customer_key),
    date_key BIGINT REFERENCES star.dim_date(date_key),
    quantity INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    revenue NUMERIC(12,2) NOT NULL
);

INSERT INTO star.dim_customer (customer_id, email, country, segment)
SELECT customer_id, email, country, segment
FROM stage.star_customers
ON CONFLICT (customer_id) DO NOTHING;

INSERT INTO star.dim_book (book_id, title, author_name, genre)
SELECT book_id, title, author_name, genre
FROM stage.books
ON CONFLICT (book_id) DO NOTHING;

INSERT INTO star.dim_date (order_date)
SELECT DISTINCT (ordered_at AT TIME ZONE 'UTC')::date
FROM stage.star_order_lines
ON CONFLICT (order_date) DO NOTHING;

INSERT INTO star.fact_order_line (order_line_id, order_id, book_key, customer_key, date_key, quantity, unit_price, revenue)
SELECT sol.order_line_id, sol.order_id, sb.book_key, sc.customer_key, sdd.date_key, sol.quantity, sol.unit_price, sol.quantity * sol.unit_price
    FROM stage.star_order_lines sol
LEFT JOIN star.dim_date sdd ON order_date = (sol.ordered_at AT TIME ZONE 'UTC')::date
LEFT JOIN star.dim_customer sc ON sol.customer_id = sc.customer_id
LEFT JOIN star.dim_book sb ON sol.book_id = sb.book_id
ON CONFLICT (order_line_id) DO NOTHING;

-- Expect 2 customers
SELECT * FROM star.dim_customer;
-- customer_key,customer_id,email,country,segment
-- 1,1,ana@shop.test,PL,Business
-- 2,2,ben@shop.test,DE,Retail

-- Expect 2 books
SELECT * FROM star.dim_book;
-- book_key,book_id,title,author_name,genre
-- 1,10,Data Systems,A. Writer,Technology
-- 2,11,River Stories,B. Novelist,Fiction

-- Expect 3 dates
SELECT * FROM star.dim_date;
-- date_key,order_date
-- 3,2026-03-12
-- 4,2026-02-05
-- 5,2026-03-22

-- Expect 4 facts
SELECT * FROM star.fact_order_line;
-- order_line_key,order_line_id,order_id,book_key,customer_key,date_key,quantity,unit_price,revenue
-- 5,1001,100,1,1,4,2,15.00,30.00
-- 6,1002,100,2,1,4,1,20.00,20.00
-- 7,1003,101,1,1,3,1,15.00,15.00
-- 8,1004,102,2,2,5,3,20.00,60.00

-- Total revenue
SELECT SUM(revenue) FROM star.fact_order_line;
-- 125.00

-- February 2026 should give Technology 30.00 and Fiction 20.00;
-- -- -- March, Technology 15.00 and Fiction 60.00.

SELECT date_trunc('month',dd.order_date)::date m1, db.genre, SUM(revenue) FROM star.fact_order_line fol
LEFT JOIN star.dim_date dd ON fol.date_key = dd.date_key
LEFT JOIN star.dim_book db ON fol.book_key = db.book_key
WHERE db.genre IN ('Technology', 'Fiction')
GROUP BY m1, db.genre
ORDER BY m1, db.genre DESC;

-- m1,genre,sum
-- 2026-02-01,Technology,30
-- 2026-02-01,Fiction,20
-- 2026-03-01,Technology,15
-- 2026-03-01,Fiction,60
