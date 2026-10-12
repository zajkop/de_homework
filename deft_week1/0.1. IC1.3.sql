/* Window Functions: Top 3 Per Customer
Task: For each customer, find their three most expensive paid orders. First total each order as
SUM(quantity * price_each). Then rank orders with ROW_NUMBER(), sorting by total
descending, then newest order, then highest order ID.
Submit: customer_id, order_id, order_total, position.
Check a customer with fewer than three paid orders. Also rank by order total only using DENSE_RANK() and explain
how tied totals behave.
 */

WITH top3PerCustomer AS (SELECT o.customer_id,
                                oi.order_id,
                                SUM(oi.quantity * oi.price_each)                                                                              order_total,
                                row_number()
                                over (PARTITION BY o.customer_id ORDER BY SUM(oi.quantity * oi.price_each) DESC, o.placed_at DESC, o.id DESC) position
                         FROM order_items oi
                                  JOIN orders o ON oi.order_id = o.id
                         WHERE o.status = 'paid'
                         GROUP BY o.customer_id, oi.order_id, o.placed_at, o.id)
SELECT *
FROM top3PerCustomer
WHERE position <= 3;
-- customer_id,order_id,order_total,position
-- 1,73,111.09,1
-- 1,29,77,2
-- 1,8,72.48,3
-- 2,41,77.2,1
-- 2,19,54.99,2
-- 2,60,52.49,3
-- 3,86,110,1
-- 3,37,107.39,2
-- 3,25,77.2,3
-- 4,21,92.48,1
-- 4,75,49.99,2
-- 4,50,49.99,3
-- 5,3,72,1
-- 5,44,52.49,2
-- 5,78,27.5,3
-- 6,10,62.1,1
-- 6,81,49.98,2
-- 7,84,56.4,1
-- 7,5,56.4,2
-- 7,56,55.44,3
-- 8,62,84.98,1
-- 8,88,81.25,2
-- 8,12,66,3
-- 9,32,50,1
-- 9,91,47,2
-- 9,65,39.9,3
-- 10,14,69.75,1
-- 10,93,49.99,2
-- 10,67,22,3
-- 11,39,79.96,1
-- 11,97,54.98,2
-- 11,9,21.5,3
-- 12,71,69.75,1
-- 12,42,26.4,2
-- 13,16,69.8,1
-- 13,77,55,2
-- 13,46,21.5,3
-- 14,18,59,1
-- 14,49,26.64,2
-- 14,80,19.99,3
-- 15,51,79.8,1
-- 15,20,40,2
-- 16,53,69.75,1
-- 16,22,19.99,2
-- 17,85,31,1
-- 17,55,29.99,2
-- 17,24,26.4,3
-- 18,26,43,1
-- 18,87,28.8,2
-- 19,59,36,1
-- 19,28,27.5,2
-- 20,92,39.9,1
-- 20,30,30,2
-- 20,61,25,3
-- 21,33,84.99,1
-- 21,94,62.1,2
-- 21,63,26.4,3
-- 22,66,51.5,1
-- 22,96,36,2
-- 22,35,24.99,3
-- 23,68,34.9,1
-- 23,38,31,2
-- 24,72,28.8,1
-- 24,40,28.8,2
-- 25,74,33.3,1
-- 26,76,43,1
-- 26,45,30,2
-- 27,79,70.9,1
-- 27,48,47,2
-- 29,70,42.5,1

-- Check a customer with fewer than three paid orders. Also rank by order total only using DENSE_RANK() and explain
-- how tied totals behave.

WITH customersWithLessThan3PaidOrders AS (SELECT customer_id
                                          FROM orders
                                          WHERE orders.status = 'paid'
                                          GROUP BY customer_id
                                          HAVING count(id) < 3)
SELECT o.customer_id,
       oi.order_id,
       SUM(oi.quantity * oi.price_each)                                                            order_total,
       dense_rank() over (partition by customer_id ORDER BY SUM(oi.quantity * oi.price_each) DESC) position
FROM order_items oi
         JOIN orders o ON oi.order_id = o.id
WHERE o.status = 'paid'
  AND customer_id IN (SELECT customer_id FROM customersWithLessThan3PaidOrders)
GROUP BY o.customer_id, oi.order_id;
-- customer_id,order_id,order_total,position
-- 6,10,62.1,1
-- 6,81,49.98,2
-- 12,71,69.75,1
-- 12,42,26.4,2
-- 15,51,79.8,1
-- 15,20,40,2
-- 16,53,69.75,1
-- 16,22,19.99,2
-- 18,26,43,1
-- 18,87,28.8,2
-- 19,59,36,1
-- 19,28,27.5,2
-- 23,68,34.9,1
-- 23,38,31,2
-- 24,40,28.8,1
-- 24,72,28.8,1
-- 25,74,33.3,1
-- 26,76,43,1
-- 26,45,30,2
-- 27,79,70.9,1
-- 27,48,47,2
-- 29,70,42.5,1

-- Explanation:
-- dense_rank assigns the same rank to tied values
-- the next rank is consecutive, with no gaps comparing to the rank function
-- e.g. values 300, 200, 200, 100 will receive 1, 2, 2, 3