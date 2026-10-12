/* Recursive CTE: Author-Influence Tree
Task: Treat authors.mentor_id as the author's mentor. Seed a chain at least four links
deep and one unrelated author. Starting from author ID 1, find every direct and indirect mentee.
Submit: One WITH RECURSIVE query returning id, name, depth, id_path. A direct
mentee has depth 1. Show the root-to-mentee path, exclude author 1 and prevent cycles by
rejecting IDs already in the path.
*/

SELECT *
FROM authors;
INSERT INTO authors
-- I will treat author '1' as 12
VALUES (12, 'Patryk Zajko', 'Germany', 2020, null),
       (13, 'Patryk Kajko', 'USA', 2020, 12),
       (14, 'Patryk Majko', 'Poland', 2020, 13),
       (15, 'Patryk Fajko', 'USA', 2020, 14),
       (16, 'Patryk Najko', 'Poland', 2020, 15),
       (17, 'Anna Zdrojewska', 'Poland', 2020, null);

WITH RECURSIVE mentors AS (
    SELECT nonRecursive.id, nonRecursive.name, 0 as depth, ARRAY[nonRecursive.id] as id_path FROM authors nonRecursive WHERE id = 12
                                            UNION ALL
    SELECT a.id, a.name, depth + 1, array_append(id_path, a.id)  FROM authors a
    JOIN mentors m ON m.id = a.mentor_id
) SELECT * FROM mentors
WHERE depth > 0;

-- id,name,depth,id_path
-- 13,Patryk Kajko,1,"{12,13}"
-- 14,Patryk Majko,2,"{12,13,14}"
-- 15,Patryk Fajko,3,"{12,13,14,15}"
-- 16,Patryk Najko,4,"{12,13,14,15,16}"

