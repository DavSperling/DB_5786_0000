-- ============================================================
-- Stage 4 - FUNCTION 2
-- Name       : calculate_period_revenue
-- Type       : FUNCTION (returns NUMERIC)
-- Purpose    : Computes the net revenue (final_amount) of the
--              restaurant for a given period [p_start, p_end]
--              by walking explicitly over the bills attached
--              to valid orders (any status except 'Cancelled').
--              Cancelled orders are skipped. If no exploitable
--              bill is found, an exception is raised.
--
-- PL/pgSQL elements used:
--   * EXPLICIT cursor (DECLARE / OPEN / FETCH / CLOSE)       [x]
--   * Record (FETCH ... INTO record)                         [x]
--   * Loop LOOP / EXIT WHEN                                  [x]
--   * Branching IF                                           [x]
--   * Implicit DML log (debug message)                       [x]
--   * Exceptions (custom + division_by_zero + OTHERS)        [x]
-- ============================================================

DROP FUNCTION IF EXISTS calculate_period_revenue(DATE, DATE);

CREATE OR REPLACE FUNCTION calculate_period_revenue(
    p_start DATE,
    p_end   DATE
) RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    -- ----- 1. Explicit cursor -----
    cur_bills CURSOR (s DATE, e DATE) FOR
        SELECT b.bill_id,
               b.final_amount,
               o.order_status,
               o.order_time
          FROM bill b
          JOIN "ORDER" o ON b.order_id = o.order_id
         WHERE o.order_time::DATE BETWEEN s AND e
         ORDER BY o.order_time;

    rec_bill        RECORD;
    v_total         NUMERIC(14,2) := 0;
    v_kept          INT           := 0;
    v_skipped       INT           := 0;
    v_avg           NUMERIC(14,2);
BEGIN
    -- ---------- 2. Argument validation ----------
    IF p_start IS NULL OR p_end IS NULL THEN
        RAISE EXCEPTION 'Period bounds cannot be NULL.'
            USING ERRCODE = '22023';
    END IF;

    IF p_end < p_start THEN
        RAISE EXCEPTION 'Invalid period: end date (%) precedes start date (%).',
                        p_end, p_start
            USING ERRCODE = '22023';
    END IF;

    -- ---------- 3. Walk the cursor explicitly ----------
    OPEN cur_bills(p_start, p_end);
    LOOP
        FETCH cur_bills INTO rec_bill;
        EXIT WHEN NOT FOUND;

        -- Branch: skip cancelled orders
        IF rec_bill.order_status = 'Cancelled' THEN
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;

        v_total := v_total + COALESCE(rec_bill.final_amount, 0);
        v_kept  := v_kept  + 1;
    END LOOP;
    CLOSE cur_bills;

    -- ---------- 4. No bill found -> raise exception ----------
    IF v_kept = 0 THEN
        RAISE EXCEPTION 'No exploitable bill between % and % (skipped=%).',
                        p_start, p_end, v_skipped
            USING ERRCODE = 'P0002';   -- NO_DATA_FOUND
    END IF;

    -- ---------- 5. Average computation (showcases division_by_zero) ----------
    v_avg := v_total / v_kept;

    RAISE NOTICE 'Period %..%: kept=%, skipped=%, revenue=% (avg=%)',
        p_start, p_end, v_kept, v_skipped, v_total, v_avg;

    RETURN v_total;

EXCEPTION
    WHEN division_by_zero THEN
        RAISE NOTICE 'calculate_period_revenue: unexpected division by zero.';
        RETURN 0;
    WHEN OTHERS THEN
        RAISE NOTICE 'calculate_period_revenue: ERROR % - %', SQLSTATE, SQLERRM;
        RAISE;
END;
$$;

COMMENT ON FUNCTION calculate_period_revenue(DATE, DATE)
IS 'F2 - Computes the net revenue between two dates by walking the bills explicitly, skipping cancelled orders.';
