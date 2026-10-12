/* Dead-Lock Reproduction

Setup: Use a development database with books 1 and 2. Open PostgreSQL sessions A and B
plus a third session to inspect locks.
Task: A runs BEGIN and updates book 1. B runs BEGIN and updates book 2. A then tries to
update book 2 and waits. Inspect that wait from the third session; then B tries to update book 1,
creating a deadlock.
Submit: The statement sequence, the deadlock error, and the blocking relationship shown with
pg_stat_activity, pg_locks and pg_blocking_pids(pid). Rollback any open
transactions. Repeat by locking both rows in ascending ID order and explain why that avoids
this deadlock.
 */

BEGIN;
UPDATE books SET title = 'Locking' WHERE id = 1;
UPDATE books SET title = 'Locking from A' WHERE id = 2;
ROLLBACK;

BEGIN;
UPDATE books SET title = 'Locking' WHERE id = 1;
UPDATE books SET title = 'Locking from A' WHERE id = 2;
ROLLBACK;