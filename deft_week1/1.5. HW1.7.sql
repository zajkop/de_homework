/* Window Frame Edge Cases

Setup: Make an events(id, event_at, amount) table with at least six events. Include
two events with identical timestamps and a gap longer than seven days.
Task 1: Compare cumulative SUM(amount) with ROWS BETWEEN UNBOUNDED PRECEDING
AND CURRENT ROW (ordered by time and unique ID) against the matching RANGE frame
(ordered by time only).
Task 2: Compare a trailing seven-row sum (ROWS BETWEEN 6 PRECEDING AND CURRENT
ROW) with a trailing seven-day sum (RANGE BETWEEN INTERVAL '7 days' PRECEDING
AND CURRENT ROW). Submit the results and explain the effects of equal timestamps and
missing dates.
 */

CREATE TABLE events
(
    id       SERIAL PRIMARY KEY,
    event_at TIMESTAMP NOT NULL,
    amount   NUMERIC   NOT NULL
);

INSERT INTO events
VALUES (1, '2023-01-01', 200),
       (2, '2023-01-01', 300),
       (3, '2023-01-03', 400),
       (4, '2023-01-04', 600),
       (5, '2023-01-05', 500),
       (6, '2023-01-13', 700)

-- Task 1: Compare cumulative SUM(amount) with ROWS BETWEEN UNBOUNDED PRECEDING
-- AND CURRENT ROW (ordered by time and unique ID) against the matching RANGE frame
-- (ordered by time only).

SELECT id,
       event_at,
       amount,
       SUM(amount) OVER (ORDER BY event_at, id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) sum1,
       SUM(amount) OVER (ORDER BY event_at RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)    sum2
FROM events;

-- 1,2023-01-01 00:00:00.000000,200,200,500
-- 2,2023-01-01 00:00:00.000000,300,500,500
-- 3,2023-01-03 00:00:00.000000,400,900,900
-- 4,2023-01-04 00:00:00.000000,600,1500,1500
-- 5,2023-01-05 00:00:00.000000,500,2000,2000
-- 6,2023-01-13 00:00:00.000000,700,2700,2700
--

-- ROWS - CURRENT ROW takes single row (order by id makes it deterministic in this case)
-- RANGE - CURRENT ROW takes all the rows matching the condition (order by event_at) so both 1st and 2nd rows got sum2 as 500

-- Task 2: Compare a trailing seven-row sum (ROWS BETWEEN 6 PRECEDING AND CURRENT
-- ROW) with a trailing seven-day sum (RANGE BETWEEN INTERVAL '7 days' PRECEDING
-- AND CURRENT ROW). Submit the results and explain the effects of equal timestamps and
-- missing dates.
--

SELECT id,
       event_at,
       amount,
       SUM(amount) OVER (ORDER BY event_at, id ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)              sum1,
       SUM(amount) OVER (ORDER BY event_at RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW) sum2
FROM events;

-- 1,2023-01-01 00:00:00.000000,200,200,500
-- 2,2023-01-01 00:00:00.000000,300,500,500
-- 3,2023-01-03 00:00:00.000000,400,900,900
-- 4,2023-01-04 00:00:00.000000,600,1500,1500
-- 5,2023-01-05 00:00:00.000000,500,2000,2000
-- 6,2023-01-13 00:00:00.000000,700,2700,700
--

-- Effects of equal timestamps and missing dates:
-- Equal timestamps as in previous examples RANGE took all rows matching event_at (observed at 1st and 2nd row)
-- Missing dates worth to observe in the last row - in case of ROWS missing dates are not taken into account
-- In case of RANGE missing dates are taken into account (last row 01-13 is 7 days after 01-06 so no other row is included into sum)