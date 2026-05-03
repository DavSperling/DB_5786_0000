-- ============================================================
-- Stage 4 - FUNCTION 1
-- Name       : get_top_loyalty_customers
-- Type       : FUNCTION (returns a REF CURSOR)
-- Purpose    : For a given loyalty tier (Bronze/Silver/Gold/
--              Platinum) and a minimum order count, returns
--              a cursor over the matching customers, ordered
--              by revenue descending, with a derived reward
--              category.
--
-- PL/pgSQL elements used:
--   * RETURN refcursor                              [x]
--   * EXPLICIT cursor (FOR rec IN cur LOOP)         [x]
--   * Record (RECORD)                               [x]
--   * Branching IF / CASE                           [x]
--   * Loop                                          [x]
--   * Exception (NO_DATA_FOUND, OTHERS, custom)     [x]
-- ============================================================

DROP FUNCTION IF EXISTS get_top_loyalty_customers(VARCHAR, INT, REFCURSOR);

CREATE OR REPLACE FUNCTION get_top_loyalty_customers(
    p_tier        VARCHAR,
    p_min_orders  INT,
    p_cursor      REFCURSOR DEFAULT 'top_loyalty_cur'
) RETURNS REFCURSOR
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    -- ---------- 1. Argument validation ----------
    IF p_tier NOT IN ('Bronze','Silver','Gold','Platinum') THEN
        RAISE EXCEPTION
            'Invalid tier "%". Allowed values: Bronze, Silver, Gold, Platinum.',
            p_tier
            USING ERRCODE = '22023';
    END IF;

    IF p_min_orders < 0 THEN
        RAISE EXCEPTION 'Minimum order count must be >= 0 (got: %).',
            p_min_orders
            USING ERRCODE = '22023';
    END IF;

    -- ---------- 2. Make sure at least one customer matches ----------
    SELECT COUNT(*)
      INTO v_count
      FROM customer            c
      JOIN loyalty             l  ON c.customer_id = l.customer_id
      JOIN loyalty_tier        lt ON l.tier_id     = lt.tier_id
      WHERE lt.level = p_tier;

    IF v_count = 0 THEN
        RAISE EXCEPTION 'No customer found for tier "%".', p_tier
            USING ERRCODE = 'P0002';   -- equivalent to NO_DATA_FOUND
    END IF;

    -- ---------- 3. Open the REF CURSOR ----------
    -- The SELECT enriches each row with a reward category derived via CASE.
    OPEN p_cursor FOR
        SELECT
            c.customer_id,
            c.first_name || ' ' || c.last_name           AS customer_name,
            lt.level                                     AS tier_level,
            l.points                                     AS loyalty_points,
            COUNT(DISTINCT o.order_id)                   AS nb_orders,
            COALESCE(SUM(b.final_amount), 0)             AS total_revenue,
            CASE
                WHEN COALESCE(SUM(b.final_amount),0) >= 2000 THEN 'GOLD_REWARD'
                WHEN COALESCE(SUM(b.final_amount),0) >= 1000 THEN 'SILVER_REWARD'
                WHEN COALESCE(SUM(b.final_amount),0) >    0 THEN 'BRONZE_REWARD'
                ELSE                                          'NO_REWARD'
            END                                          AS reward_category
        FROM       customer       c
        JOIN       loyalty        l  ON c.customer_id = l.customer_id
        JOIN       loyalty_tier   lt ON l.tier_id     = lt.tier_id
        LEFT JOIN  "ORDER"        o  ON c.customer_id = o.customer_id
        LEFT JOIN  bill           b  ON o.order_id    = b.order_id
        WHERE      lt.level = p_tier
        GROUP BY   c.customer_id, c.first_name, c.last_name, lt.level, l.points
        HAVING     COUNT(DISTINCT o.order_id) >= p_min_orders
        ORDER BY   total_revenue DESC, l.points DESC;

    RAISE NOTICE 'Cursor "%" opened: tier=% / min_orders=% / matching_customers=%',
                 p_cursor, p_tier, p_min_orders, v_count;

    RETURN p_cursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'get_top_loyalty_customers: ERROR % - %',
            SQLSTATE, SQLERRM;
        RAISE;       -- re-raise to signal the failure to the caller
END;
$$;

COMMENT ON FUNCTION get_top_loyalty_customers(VARCHAR, INT, REFCURSOR)
IS 'F1 - Returns a REF CURSOR over the top customers of a given loyalty tier, ordered by revenue, with a derived reward category.';
