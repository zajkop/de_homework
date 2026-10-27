-- Slowly Changing Dimension Type 2
--
-- Build scd.dim_customer with a generated surrogate customer_key, customer_id,
-- country, segment, valid_from and valid_to. Use TIMESTAMPTZ for the validity
-- columns. Load stage.scd_customer_events batch 1, then batch 2, in one
-- transaction per batch. Deduplicate by event_id and process events in occurred_at
-- order. Insert new customers, but add a version for an existing customer only when
-- country or segment changes. Do not delete or reinsert existing versions or change
-- their keys. Use [valid_from, valid_to), with NULL valid_to for the current version.
-- Prevent overlaps and multiple current versions per customer. There are no
-- late-arriving changes.
-- Check your work: Batch 1 should create two Retail rows. Batch 2 should close
-- customer 1's Retail version at 2026-03-01 00:00:00+00 and add a Business row.
-- Expect three versions, with both original keys intact. Replayed or unchanged events
-- must add no versions. Rerunning batch 2 must preserve rows, keys and intervals.
-- Join stage.star_order_lines to the version valid at ordered_at: revenue should be
-- Retail 110.00 and Business 15.00. Test stage.scd_probe_orders separately: order
-- 901, just before the change, should match Retail; order 902, exactly at the change,
-- should match Business. Each order must match exactly once. Leave these test
-- orders out of sales totals.

CREATE SCHEMA IF NOT EXISTS scd;
CREATE EXTENSION btree_gist;
DROP TABLE IF EXISTS scd.dim_customer;
CREATE TABLE IF NOT EXISTS scd.dim_customer
(
    customer_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  BIGINT      NOT NULL,
    country      text        NOT NULL,
    segment      text        NOT NULL,
    valid_from   TIMESTAMPTZ NOT NULL,
    valid_to     TIMESTAMPTZ CHECK (valid_to IS NULL OR valid_to > valid_from),
    EXCLUDE USING gist (customer_id WITH =, tstzrange(valid_from, valid_to, '[)') WITH &&)
);

BEGIN;
CREATE TEMP TABLE changes ON COMMIT DROP AS (WITH dedupeByEventId AS (SELECT DISTINCT ON (sce.event_id) sce.event_id,
                                                                                                        sce.customer_id,
                                                                                                        sce.country,
                                                                                                        sce.segment,
                                                                                                        sce.occurred_at
                                                                      FROM stage.scd_customer_events sce
                                                                               LEFT JOIN scd.dim_customer dm
                                                                                         ON dm.customer_id =
                                                                                            sce.customer_id
                                                                                             AND dm.valid_to IS NULL
                                                                      WHERE batch_id = 1
                                                                        AND (dm.customer_id IS NULL
                                                                          OR sce.country != dm.country
                                                                          OR sce.segment != dm.segment))
                                             SELECT DISTINCT ON (customer_id) *
                                             FROM dedupeByEventId
                                             ORDER BY customer_id, occurred_at);

SELECT *
FROM changes;

UPDATE scd.dim_customer dc
SET valid_to = occurred_at
FROM changes
WHERE dc.customer_id = changes.customer_id
  AND dc.valid_to IS NULL;

INSERT INTO scd.dim_customer (customer_id, country, segment, valid_from, valid_to)
SELECT customer_id, country, segment, occurred_at, NULL
FROM changes;
COMMIT;

BEGIN;
CREATE TEMP TABLE changes ON COMMIT DROP AS (WITH dedupeByEventId AS (SELECT DISTINCT ON (sce.event_id) sce.event_id,
                                                                                                        sce.customer_id,
                                                                                                        sce.country,
                                                                                                        sce.segment,
                                                                                                        sce.occurred_at
                                                                      FROM stage.scd_customer_events sce
                                                                               LEFT JOIN scd.dim_customer dm
                                                                                         ON dm.customer_id =
                                                                                            sce.customer_id
                                                                                             AND dm.valid_to IS NULL
                                                                      WHERE batch_id = 2
                                                                        AND (dm.customer_id IS NULL
                                                                          OR sce.country != dm.country
                                                                          OR sce.segment != dm.segment))
                                             SELECT DISTINCT ON (customer_id) *
                                             FROM dedupeByEventId
                                             ORDER BY customer_id, occurred_at);

SELECT *
FROM changes;

UPDATE scd.dim_customer dc
SET valid_to = occurred_at
FROM changes
WHERE dc.customer_id = changes.customer_id
  AND dc.valid_to IS NULL;

INSERT INTO scd.dim_customer (customer_id, country, segment, valid_from, valid_to)
SELECT customer_id, country, segment, occurred_at, NULL
FROM changes;
COMMIT;

SELECT *
FROM scd.dim_customer;
-- customer_key,customer_id,country,segment,valid_from,valid_to
-- 2,2,DE,Retail,2026-01-15 00:00:00.000000 +00:00,
-- 1,1,PL,Retail,2026-01-01 00:00:00.000000 +00:00,2026-03-01 00:00:00.000000 +00:00
-- 3,1,PL,Business,2026-03-01 00:00:00.000000 +00:00,

SELECT scd.dim_customer.segment, SUM(stage.star_order_lines.quantity * stage.star_order_lines.unit_price)
FROM scd.dim_customer
         LEFT JOIN stage.star_order_lines ON scd.dim_customer.customer_id = stage.star_order_lines.customer_id AND
                                             (stage.star_order_lines.ordered_at < scd.dim_customer.valid_to OR
                                              scd.dim_customer.valid_to IS NULL) AND
                                             stage.star_order_lines.ordered_at >= scd.dim_customer.valid_from
group by scd.dim_customer.segment;

-- segment,sum
-- Retail,110
-- Business,15