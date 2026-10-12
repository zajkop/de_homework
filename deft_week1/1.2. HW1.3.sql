/* Recursive CTE: Manager Hierarchy

Setup: Create employees(id, manager_id, name, salary) with a self-referencing
manager foreign key. Add at least eight employees, two employees with no manager, and a
chain reaching at least three management levels.
Task 1: For every employee, show their ID, name, depth below a top-level manager, and
complete manager-to-employee path. Task 2: For every employee, sum the salaries of all direct
and indirect reports (but not their own). Employees without reports must have a total of 0.
Submit: Both recursive queries and example results for a top-level manager and an employee
with no reports. Show how the queries avoid cycles.
 */

CREATE TABLE employees
(
    id         BIGSERIAL PRIMARY KEY,
    manager_id BIGINT REFERENCES employees (id) ON DELETE SET NULL,
    name       TEXT   NOT NULL,
    salary     NUMERIC
);

INSERT INTO employees
VALUES (1, null, 'Jan Bak', 10000),
       (2, 1, 'Karolina Bak', 20000),
       (3, 2, 'Patryk Bak', 30000),
       (4, 3, 'Dawid Bak', 40000),
       (5, 4, 'Damian Bak', 50000),
       (6, 1, 'Kornelia Bak', 60000),
       (7, 2, 'Stefan Bak', 20000),
       (8, null, 'Monika Bak', 50000);


-- Task 1
WITH RECURSIVE managerRecursive AS (SELECT id, name, 0 as depth, ARRAY [id] as path
                                    FROM employees
                                    WHERE manager_id IS NULL
                                    UNION ALL
                                    SELECT e.id, e.name, mr.depth + 1, array_append(mr.path, e.id)
                                    FROM employees e
                                             JOIN managerRecursive mr ON e.manager_id = mr.id
                                    WHERE e.id <> ALL (mr.path))
SELECT id, name, depth, path
FROM managerRecursive
ORDER BY id, depth, path;

-- id,name,depth,path
-- 1,Jan Bak,0,{1}
-- 2,Karolina Bak,1,"{1,2}"
-- 3,Patryk Bak,2,"{1,2,3}"
-- 4,Dawid Bak,3,"{1,2,3,4}"
-- 5,Damian Bak,4,"{1,2,3,4,5}"
-- 6,Kornelia Bak,1,"{1,6}"
-- 7,Stefan Bak,2,"{1,2,7}"
-- 8,Monika Bak,0,{8}


-- Task 2
WITH RECURSIVE sub AS (SELECT id as tree_top, id, salary, name, ARRAY [id] as path
                       FROM employees
                       UNION ALL
                       SELECT s.tree_top, e.id, e.salary, s.name, array_append(s.path, e.id)
                       FROM employees e
                                JOIN sub s ON e.manager_id = s.id
                       WHERE e.id <> ALL (s.path))
SELECT tree_top, name, COALESCE(SUM(salary) FILTER ( WHERE tree_top <> id ),0) sum
FROM sub
GROUP BY tree_top, name;
-- 1,Jan Bak,220000
-- 2,Karolina Bak,140000
-- 3,Patryk Bak,90000
-- 4,Dawid Bak,50000
-- 5,Damian Bak,
-- 6,Kornelia Bak,
-- 7,Stefan Bak,
-- 8,Monika Bak,


-- Explain
-- Queries avoid cycles by ensuring that each path is unique and that the manager is not the same as the employee
-- WHERE e.id <> ALL(s.path)