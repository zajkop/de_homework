CREATE EXTENSION IF NOT EXISTS citext;
CREATE TABLE authors (
                         id BIGSERIAL PRIMARY KEY,
                         name TEXT NOT NULL,
                         country TEXT,
                         born_year INT CHECK (born_year > 1000),
                         mentor_id BIGINT REFERENCES authors(id) ON DELETE SET NULL,
                         CHECK (mentor_id IS DISTINCT FROM id)
);
CREATE TABLE books (
                       id BIGSERIAL PRIMARY KEY,
                       author_id BIGINT NOT NULL REFERENCES authors(id) ON DELETE RESTRICT,
                       title TEXT NOT NULL,
                       isbn VARCHAR(13) UNIQUE CHECK (isbn ~ '^[0-9]{13}$'),
                       price NUMERIC(8,2) NOT NULL CHECK (price >= 0),
                       published_at DATE NOT NULL
);
CREATE TABLE customers (
                           id BIGSERIAL PRIMARY KEY,
                           email CITEXT UNIQUE NOT NULL,
                           country TEXT,
                           created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE orders (
                        id BIGSERIAL PRIMARY KEY,
                        customer_id BIGINT NOT NULL REFERENCES customers(id),
                        placed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        status TEXT NOT NULL CHECK (
                            status IN ('pending', 'paid', 'cancelled', 'refunded')
                            )
);
CREATE TABLE order_items (
                             order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
                             book_id BIGINT NOT NULL REFERENCES books(id),
                             quantity INT NOT NULL CHECK (quantity > 0),
                             price_each NUMERIC(8,2) NOT NULL CHECK (price_each >= 0),
                             PRIMARY KEY (order_id, book_id)
);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_placed ON orders(placed_at);
CREATE INDEX idx_books_author ON books(author_id);

-- =====================================================================
-- Test data
-- =====================================================================
BEGIN;

INSERT INTO authors (id, name, country, born_year, mentor_id) VALUES
    (1,  'Anna Kowalska',    'Poland',  1948, NULL),
    (2,  'Jan Nowak',        'Poland',  1965, 1),
    (3,  'Marta Wiśniewska', 'Poland',  1982, 2),
    (4,  'John Carter',      'USA',     1955, NULL),
    (5,  'Emily Stone',      'USA',     1978, 4),
    (6,  'Oliver Hughes',    'UK',      1970, 4),
    (7,  'Sophie Laurent',   'France',  1975, NULL),
    (8,  'Lukas Becker',     'Germany', 1968, 7),
    (9,  'Elena García',     'Spain',   1985, 8),
    (10, 'Hiro Tanaka',      'Japan',   1990, NULL),
    (11, 'Clara Rossi',      'Italy',   1995, 7);

INSERT INTO books (id, author_id, title, isbn, price, published_at) VALUES
    (1,  1,  'The Silent River',         '9780000000001', 39.90, '1985-04-12'),
    (2,  1,  'Winter in Kraków',         '9780000000002', 42.50, '1992-10-03'),
    (3,  1,  'Letters from the Vistula', '9780000000003', 35.00, '2004-03-21'),
    (4,  2,  'Shadows of the Old Town',  '9780000000004', 29.99, '1998-06-15'),
    (5,  2,  'Glass Mountains',          '9780000000005', 34.90, '2010-09-01'),
    (6,  3,  'Digital Ghosts',           '9780000000006', 24.99, '2015-02-14'),
    (7,  3,  'Ninety Days of Rain',      '9780000000007', 27.50, '2021-11-05'),
    (8,  4,  'Dust and Steel',           '9780000000008', 45.00, '1988-08-20'),
    (9,  4,  'The Last Frontier',        '9780000000009', 49.99, '1995-05-30'),
    (10, 4,  'Highway Seven',            '9780000000010', 19.99, '2003-07-07'),
    (11, 5,  'Neon Hearts',              '9780000000011', 22.00, '2012-01-19'),
    (12, 5,  'Paper Planets',            '9780000000012', 25.00, '2019-09-09'),
    (13, 6,  'Fog over Thames',          '9780000000013', 31.00, '2001-03-03'),
    (14, 6,  'The Cartographer',         '9780000000014', 38.75, '2014-10-10'),
    (15, 7,  'Lumière',                  '9780000000015', 33.30, '1999-12-01'),
    (16, 7,  'Rue des Rêves',            '9780000000016', 28.80, '2008-04-04'),
    (17, 8,  'Iron Forest',              '9780000000017', 36.00, '1996-02-02'),
    (18, 8,  'Northern Lights Express',  '9780000000018', 41.20, '2011-06-06'),
    (19, 9,  'Saffron Coast',            '9780000000019', 26.40, '2017-05-05'),
    (20, 9,  'Midnight in Seville',      '9780000000020', 30.00, '2023-03-15'),
    (21, 10, 'Cherry Blossom Code',      '9780000000021', 21.50, '2020-04-01'),
    (22, 10, 'Tokyo Algorithms',         '9780000000022', 55.00, '2025-11-20');

INSERT INTO customers (id, email, country, created_at) VALUES
    (1,  'alice.smith@example.com',       'USA',         '2025-01-10 09:00:00+00'),
    (2,  'bob.jones@example.com',         'UK',          '2025-01-22 09:00:00+00'),
    (3,  'piotr.kowalski@example.pl',     'Poland',      '2025-02-05 09:00:00+00'),
    (4,  'kasia.zielinska@example.pl',    'Poland',      '2025-02-18 09:00:00+00'),
    (5,  'hans.mueller@example.de',       'Germany',     '2025-03-03 09:00:00+00'),
    (6,  'marie.dubois@example.fr',       'France',      '2025-03-17 09:00:00+00'),
    (7,  'carlos.lopez@example.es',       'Spain',       '2025-04-01 09:00:00+00'),
    (8,  'giulia.bianchi@example.it',     'Italy',       '2025-04-15 09:00:00+00'),
    (9,  'emma.brown@example.com',        'USA',         '2025-05-02 09:00:00+00'),
    (10, 'liam.wilson@example.co.uk',     'UK',          '2025-05-20 09:00:00+00'),
    (11, 'tomasz.lewandowski@example.pl', 'Poland',      '2025-06-08 09:00:00+00'),
    (12, 'anna.nowak@example.pl',         'Poland',      '2025-06-25 09:00:00+00'),
    (13, 'jan.novak@example.cz',          'Czechia',     '2025-07-09 09:00:00+00'),
    (14, 'sven.larsson@example.se',       'Sweden',      '2025-07-28 09:00:00+00'),
    (15, 'sanne.devries@example.nl',      'Netherlands', '2025-08-12 09:00:00+00'),
    (16, 'noah.miller@example.com',       'USA',         '2025-08-30 09:00:00+00'),
    (17, 'olivia.taylor@example.com',     NULL,          '2025-09-14 09:00:00+00'),
    (18, 'lucas.martin@example.fr',       'France',      '2025-10-01 09:00:00+00'),
    (19, 'lena.schmidt@example.de',       'Germany',     '2025-10-19 09:00:00+00'),
    (20, 'pablo.sanchez@example.es',      'Spain',       '2025-11-03 09:00:00+00'),
    (21, 'marco.ricci@example.it',        'Italy',       '2025-11-21 09:00:00+00'),
    (22, 'ewa.wojcik@example.pl',         'Poland',      '2025-12-06 09:00:00+00'),
    (23, 'james.anderson@example.com',    'USA',         '2025-12-22 09:00:00+00'),
    (24, 'sophie.clark@example.co.uk',    'UK',          '2026-01-08 09:00:00+00'),
    (25, 'michal.kaminski@example.pl',    'Poland',      '2026-01-26 09:00:00+00'),
    (26, 'eva.svobodova@example.cz',      'Czechia',     '2026-02-10 09:00:00+00'),
    (27, 'felix.wagner@example.de',       'Germany',     '2026-02-24 09:00:00+00'),
    (28, 'chloe.bernard@example.fr',      'France',      '2026-05-02 09:00:00+00'),
    (29, 'zofia.mazur@example.pl',        'Poland',      '2026-08-15 09:00:00+00'),
    (30, 'ethan.moore@example.com',       'USA',         '2026-09-25 09:00:00+00');

INSERT INTO orders (id, customer_id, placed_at, status) VALUES
    (1,   1,  '2026-03-02 10:15:00+00', 'paid'),
    (2,   3,  '2026-03-05 14:30:00+00', 'paid'),
    (3,   5,  '2026-03-08 09:45:00+00', 'paid'),
    (4,   2,  '2026-03-11 16:20:00+00', 'cancelled'),
    (5,   7,  '2026-03-14 11:05:00+00', 'paid'),
    (6,   4,  '2026-03-18 13:40:00+00', 'paid'),
    (7,   9,  '2026-03-21 15:55:00+00', 'refunded'),
    (8,   1,  '2026-03-25 10:30:00+00', 'paid'),
    (9,   11, '2026-03-29 12:10:00+00', 'paid'),
    (10,  6,  '2026-04-02 09:20:00+00', 'paid'),
    (11,  3,  '2026-04-06 17:45:00+00', 'paid'),
    (12,  8,  '2026-04-09 11:30:00+00', 'paid'),
    (13,  12, '2026-04-12 14:00:00+00', 'cancelled'),
    (14,  10, '2026-04-15 10:50:00+00', 'paid'),
    (15,  1,  '2026-04-19 16:10:00+00', 'paid'),
    (16,  13, '2026-04-22 12:35:00+00', 'paid'),
    (17,  5,  '2026-04-26 15:25:00+00', 'refunded'),
    (18,  14, '2026-04-29 09:05:00+00', 'paid'),
    (19,  2,  '2026-05-01 13:15:00+00', 'paid'),
    (20,  15, '2026-05-04 10:40:00+00', 'paid'),
    (21,  4,  '2026-05-07 18:20:00+00', 'paid'),
    (22,  16, '2026-05-10 11:55:00+00', 'paid'),
    (23,  6,  '2026-05-13 14:45:00+00', 'cancelled'),
    (24,  17, '2026-05-16 09:30:00+00', 'paid'),
    (25,  3,  '2026-05-19 16:05:00+00', 'paid'),
    (26,  18, '2026-05-22 12:20:00+00', 'paid'),
    (27,  7,  '2026-05-26 10:10:00+00', 'refunded'),
    (28,  19, '2026-05-29 15:35:00+00', 'paid'),
    (29,  1,  '2026-06-02 11:25:00+00', 'paid'),
    (30,  20, '2026-06-05 14:50:00+00', 'paid'),
    (31,  28, '2026-06-08 10:00:00+00', 'cancelled'),
    (32,  9,  '2026-06-11 16:40:00+00', 'paid'),
    (33,  21, '2026-06-14 12:15:00+00', 'paid'),
    (34,  8,  '2026-06-17 09:55:00+00', 'paid'),
    (35,  22, '2026-06-20 13:30:00+00', 'paid'),
    (36,  10, '2026-06-23 17:10:00+00', 'refunded'),
    (37,  3,  '2026-06-26 10:45:00+00', 'paid'),
    (38,  23, '2026-06-29 15:00:00+00', 'paid'),
    (39,  11, '2026-07-02 12:40:00+00', 'paid'),
    (40,  24, '2026-07-05 10:20:00+00', 'paid'),
    (41,  2,  '2026-07-08 14:15:00+00', 'paid'),
    (42,  12, '2026-07-11 16:55:00+00', 'paid'),
    (43,  25, '2026-07-14 09:35:00+00', 'cancelled'),
    (44,  5,  '2026-07-17 11:50:00+00', 'paid'),
    (45,  26, '2026-07-20 13:25:00+00', 'paid'),
    (46,  13, '2026-07-23 15:45:00+00', 'paid'),
    (47,  1,  '2026-07-26 10:05:00+00', 'refunded'),
    (48,  27, '2026-07-29 17:30:00+00', 'paid'),
    (49,  14, '2026-08-01 12:00:00+00', 'paid'),
    (50,  4,  '2026-08-04 14:35:00+00', 'paid'),
    (51,  15, '2026-08-07 10:25:00+00', 'paid'),
    (52,  6,  '2026-08-10 16:15:00+00', 'cancelled'),
    (53,  16, '2026-08-13 11:40:00+00', 'paid'),
    (54,  3,  '2026-08-16 13:55:00+00', 'paid'),
    (55,  17, '2026-08-19 09:15:00+00', 'paid'),
    (56,  7,  '2026-08-22 15:20:00+00', 'paid'),
    (57,  18, '2026-08-25 12:50:00+00', 'refunded'),
    (58,  1,  '2026-08-28 10:35:00+00', 'paid'),
    (59,  19, '2026-09-01 09:40:00+00', 'paid'),
    (60,  2,  '2026-09-02 11:15:00+00', 'paid'),
    (61,  20, '2026-09-03 14:25:00+00', 'paid'),
    (62,  8,  '2026-09-04 10:05:00+00', 'paid'),
    (63,  21, '2026-09-05 09:30:00+00', 'paid'),
    (64,  3,  '2026-09-05 16:45:00+00', 'paid'),
    (65,  9,  '2026-09-06 12:20:00+00', 'paid'),
    (66,  22, '2026-09-07 13:10:00+00', 'paid'),
    (67,  10, '2026-09-08 10:55:00+00', 'paid'),
    (68,  23, '2026-09-09 11:35:00+00', 'paid'),
    (69,  11, '2026-09-09 15:50:00+00', 'refunded'),
    (70,  29, '2026-09-10 12:45:00+00', 'paid'),
    (71,  12, '2026-09-11 09:25:00+00', 'paid'),
    (72,  24, '2026-09-12 14:05:00+00', 'paid'),
    (73,  1,  '2026-09-14 10:15:00+00', 'paid'),
    (74,  25, '2026-09-15 16:30:00+00', 'paid'),
    (75,  4,  '2026-09-16 11:45:00+00', 'paid'),
    (76,  26, '2026-09-17 13:35:00+00', 'paid'),
    (77,  13, '2026-09-18 09:50:00+00', 'paid'),
    (78,  5,  '2026-09-18 17:20:00+00', 'paid'),
    (79,  27, '2026-09-19 12:10:00+00', 'paid'),
    (80,  14, '2026-09-20 14:40:00+00', 'paid'),
    (81,  6,  '2026-09-21 10:30:00+00', 'paid'),
    (82,  15, '2026-09-22 11:05:00+00', 'cancelled'),
    (83,  16, '2026-09-22 15:15:00+00', 'pending'),
    (84,  7,  '2026-09-23 09:45:00+00', 'paid'),
    (85,  17, '2026-09-24 13:20:00+00', 'paid'),
    (86,  3,  '2026-09-25 16:00:00+00', 'paid'),
    (87,  18, '2026-09-26 10:40:00+00', 'paid'),
    (88,  8,  '2026-09-27 12:30:00+00', 'paid'),
    (89,  19, '2026-09-27 18:05:00+00', 'pending'),
    (90,  1,  '2026-09-28 11:20:00+00', 'paid'),
    (91,  9,  '2026-09-29 14:50:00+00', 'paid'),
    (92,  20, '2026-09-30 10:10:00+00', 'paid'),
    (93,  10, '2026-10-01 10:25:00+00', 'paid'),
    (94,  21, '2026-10-02 13:45:00+00', 'paid'),
    (95,  2,  '2026-10-03 11:10:00+00', 'pending'),
    (96,  22, '2026-10-05 15:30:00+00', 'paid'),
    (97,  11, '2026-10-06 09:55:00+00', 'paid'),
    (98,  23, '2026-10-07 14:20:00+00', 'pending'),
    (99,  4,  '2026-10-09 12:35:00+00', 'pending'),
    (100, 24, '2026-10-10 16:50:00+00', 'pending');

INSERT INTO order_items (order_id, book_id, quantity, price_each)
SELECT v.order_id,
       v.book_id,
       v.quantity,
       CASE
           WHEN v.book_id IN (1, 8, 9) AND o.placed_at < '2026-07-01 00:00:00+00' THEN b.price - 5.00
           WHEN v.book_id = 22 AND o.placed_at < '2026-06-01 00:00:00+00' THEN 59.00
           WHEN v.book_id = 15 AND o.placed_at >= '2026-08-01 00:00:00+00'
                               AND o.placed_at <  '2026-09-01 00:00:00+00' THEN ROUND(b.price * 0.80, 2)
           ELSE b.price
       END
FROM (VALUES
    (1, 1, 1), (1, 4, 1),
    (2, 8, 1),
    (3, 17, 2),
    (4, 9, 1),
    (5, 19, 1), (5, 20, 1),
    (6, 2, 1),
    (7, 13, 1),
    (8, 6, 1), (8, 7, 1), (8, 10, 1),
    (9, 21, 1),
    (10, 15, 1), (10, 16, 1),
    (11, 9, 1),
    (12, 11, 3),
    (13, 14, 1),
    (14, 13, 1), (14, 14, 1),
    (15, 1, 1),
    (16, 5, 2),
    (17, 18, 1),
    (18, 22, 1),
    (19, 4, 1), (19, 12, 1),
    (20, 8, 1),
    (21, 2, 1), (21, 6, 2),
    (22, 10, 1),
    (23, 16, 1),
    (24, 19, 1),
    (25, 17, 1), (25, 18, 1),
    (26, 21, 2),
    (27, 1, 1),
    (28, 7, 1),
    (29, 22, 1), (29, 11, 1),
    (30, 20, 1),
    (31, 15, 1),
    (32, 12, 2),
    (33, 9, 1), (33, 8, 1),
    (34, 5, 1),
    (35, 6, 1),
    (36, 14, 1),
    (37, 2, 1), (37, 1, 1), (37, 4, 1),
    (38, 13, 1),
    (39, 10, 4),
    (40, 16, 1),
    (41, 18, 1), (41, 17, 1),
    (42, 19, 1),
    (43, 22, 1),
    (44, 7, 1), (44, 6, 1),
    (45, 20, 1),
    (46, 21, 1),
    (47, 8, 1),
    (48, 11, 1), (48, 12, 1),
    (49, 15, 1),
    (50, 9, 1),
    (51, 1, 2),
    (52, 5, 1),
    (53, 13, 1), (53, 14, 1),
    (54, 2, 1),
    (55, 4, 1),
    (56, 16, 1), (56, 15, 1),
    (57, 22, 1),
    (58, 18, 1),
    (59, 17, 1),
    (60, 6, 1), (60, 7, 1),
    (61, 12, 1),
    (62, 8, 1), (62, 10, 2),
    (63, 19, 1),
    (64, 22, 1),                  -- 55.00
    (65, 1, 1),
    (66, 20, 1), (66, 21, 1),
    (67, 11, 1),
    (68, 5, 1),
    (69, 9, 1),
    (70, 2, 1),
    (71, 14, 1), (71, 13, 1),
    (72, 16, 1),
    (73, 4, 1), (73, 1, 1), (73, 18, 1),
    (74, 15, 1),
    (75, 9, 1),
    (76, 21, 2),
    (77, 20, 1), (77, 12, 1),
    (78, 7, 1),
    (79, 17, 1), (79, 5, 1),
    (80, 10, 1),
    (81, 6, 2),
    (82, 8, 1),
    (83, 11, 1),
    (84, 19, 1), (84, 20, 1),
    (85, 13, 1),
    (86, 22, 2),
    (87, 16, 1),
    (88, 2, 1), (88, 14, 1),
    (89, 4, 1),
    (90, 18, 1),
    (91, 12, 1), (91, 11, 1),
    (92, 1, 1),
    (93, 9, 1),
    (94, 15, 1), (94, 16, 1),
    (95, 21, 1),
    (96, 17, 1),
    (97, 6, 1), (97, 4, 1),
    (98, 22, 1),
    (99, 8, 1), (99, 2, 1),
    (100, 10, 1)
) AS v(order_id, book_id, quantity)
JOIN books b ON b.id = v.book_id
JOIN orders o ON o.id = v.order_id;

COMMIT;

-- =====================================================================
-- Verify and submit
-- =====================================================================

-- Duplicate emails
UPDATE customers SET email = 'felix.wagner@example.de' WHERE id = 28;
--
-- [23505] ERROR: duplicate key value violates unique constraint "customers_email_key"
--   Szczegóły: Key (email)=(felix.wagner@example.de) already exists.
--
UPDATE customers SET email = 'felix.WAGNER@example.de' WHERE id = 28;
--
-- [23505] ERROR: duplicate key value violates unique constraint "customers_email_key"
--   Szczegóły: Key (email)=(felix.WAGNER@example.de) already exists.
--

-- Negative prices
INSERT INTO books VALUES
                      (23, 1, 'Book with negative price', '9780000000005', -55, '2026-04-14')
--
-- [23514] ERROR: new row for relation "books" violates check constraint "books_price_check"
--   Szczegóły: Failing row contains (23, 1, Book with negative price, 9780000000005, -55.00, 2026-04-14).
--

-- Invalid foreign key
INSERT INTO authors VALUES (55, 'Author with not existing mentor', 'PL', 2000, 108)
--
-- [23503] ERROR: insert or update on table "authors" violates foreign key constraint "authors_mentor_id_fkey"
--   Szczegóły: Key (mentor_id)=(108) is not present in table "authors".
--

-- Restricted author deletion
DELETE FROM authors WHERE id = 1;
--
-- [23503] ERROR: update or delete on table "authors" violates foreign key constraint "books_author_id_fkey" on table "books"
--   Szczegóły: Key (id)=(1) is still referenced from table "books".
--

-- Cascade deletion
BEGIN;
SELECT * FROM order_items WHERE order_id = 1;
--
-- order_id,book_id,quantity,price_each
-- 1,4,1,29.99
-- 1,1,1,34.90
--
DELETE FROM orders WHERE id = 1;
SELECT * FROM order_items WHERE order_id = 1;
-- 0 rows
ROLLBACK;
