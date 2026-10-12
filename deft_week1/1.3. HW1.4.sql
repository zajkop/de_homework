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

-- Inspect that wait from the third session
SELECT pid,
       state,
       wait_event_type,
       wait_event,
       pg_blocking_pids(pid) AS blocked_by,
       query
FROM pg_stat_activity
WHERE datname = current_database()
  AND pid <> pg_backend_pid()
ORDER BY pid;

-- 390,active,Lock,transactionid,{392},UPDATE books SET title = 'Locking from A' WHERE id = 2

SELECT pid, locktype, mode, granted, relation::regclass AS relation, transactionid
FROM pg_locks
WHERE pid <> pg_backend_pid()
ORDER BY pid, granted;

-- pid,locktype,mode,granted,relation,transactionid
    -- Session A wants to obtain the lock which is hold by Session B
-- 390,transactionid,ShareLock,false,,826
-- 390,transactionid,ExclusiveLock,true,,824
-- 390,transactionid,ExclusiveLock,true,,827
-- 390,tuple,ExclusiveLock,true,books,
-- 390,relation,RowExclusiveLock,true,idx_books_author,
-- 390,relation,RowExclusiveLock,true,books_pkey,
-- 390,relation,RowExclusiveLock,true,books,
-- 390,relation,RowExclusiveLock,true,books_isbn_key,
-- 390,virtualxid,ExclusiveLock,true,,
    -- Session B holds the lock - unless it's released session A won't proceed
-- 392,transactionid,ExclusiveLock,true,,826

-- Explanation
-- "Repeat by locking both rows in ascending ID order and explain why that avoids this deadlock."
-- Both sessions update book 1 first, then book 2.
-- B blocks already on book 1 and holds no locks yet, so A can update book 2, finish and release both rows.
-- Then B continues. B waits for A, but A never waits for B - there is no cycle, so no deadlock.
-- A deadlock needs each transaction to hold a lock the other one wants, which can't happen when all of them lock rows in the same order.
