-- ============================================================
-- Stage 4 - PROCEDURE 2
-- Name       : generate_monthly_waiter_report
-- Type       : PROCEDURE
-- Purpose    : Generates (or regenerates) a monthly per-waiter
--              report and stores it in MONTHLY_WAITER_REPORT
--              (created via AlterTable.sql).
--              Each waiter is classified as HIGH / MEDIUM / LOW
--              depending on their monthly revenue.
--              Showcases the IMPLICIT cursor through FOR ... IN
--              (record loop without an explicit declaration).
--
-- PL/pgSQL elements used:
--   * IMPLICIT cursor (FOR rec IN <query>)                  [x]
--   * Record                                                [x]
--   * FOR loop                                              [x]
--   * Branching IF / ELSIF                                  [x]
--   * DML: DELETE existing rows + INSERT (logical UPSERT)   [x]
--   * Exceptions (raise_exception, OTHERS)                  [x]
--   * RAISE NOTICE for execution proof                      [x]
-- ============================================================

DROP PROCEDURE IF EXISTS generate_monthly_waiter_report(INT, INT);

CREATE OR REPLACE PROCEDURE generate_monthly_waiter_report(
    p_year  INT,
    p_month INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    rec               RECORD;
    v_total_revenue   NUMERIC(14,2) := 0;
    v_total_orders    INT           := 0;
    v_perf            VARCHAR(10);
    v_inserted        INT           := 0;
BEGIN
    -- ---------- 1. Parameter validation ----------
    IF p_year IS NULL OR p_month IS NULL THEN
        RAISE EXCEPTION 'Year and month cannot be NULL.'
            USING ERRCODE = '22023';
    END IF;

    IF p_month < 1 OR p_month > 12 THEN
        RAISE EXCEPTION 'Invalid month (got: %).', p_month
            USING ERRCODE = '22023';
    END IF;

    -- ---------- 2. Purge previous rows for this (year, month) ----------
    DELETE FROM MONTHLY_WAITER_REPORT
     WHERE report_year  = p_year
       AND report_month = p_month;

    -- ---------- 3. IMPLICIT cursor: FOR rec IN <query> ----------
    FOR rec IN
        SELECT o.waiter_id,
               COUNT(DISTINCT o.order_id)              AS nb_orders,
               COALESCE(SUM(b.final_amount), 0)        AS total_revenue,
               COALESCE(AVG(b.final_amount), 0)        AS avg_bill
          FROM "ORDER" o
          LEFT JOIN bill b ON o.order_id = b.order_id
         WHERE EXTRACT(YEAR  FROM o.order_time) = p_year
           AND EXTRACT(MONTH FROM o.order_time) = p_month
         GROUP BY o.waiter_id
         ORDER BY total_revenue DESC
    LOOP
        -- Branching: performance level
        IF rec.total_revenue >= 1500 THEN
            v_perf := 'HIGH';
        ELSIF rec.total_revenue >= 500 THEN
            v_perf := 'MEDIUM';
        ELSE
            v_perf := 'LOW';
        END IF;

        -- DML: INSERT into the report table
        INSERT INTO MONTHLY_WAITER_REPORT(
            report_year, report_month, waiter_id,
            nb_orders, total_revenue, avg_bill, perf_level
        )
        VALUES (
            p_year, p_month, rec.waiter_id,
            rec.nb_orders, rec.total_revenue,
            ROUND(rec.avg_bill, 2), v_perf
        );

        v_total_revenue := v_total_revenue + rec.total_revenue;
        v_total_orders  := v_total_orders  + rec.nb_orders;
        v_inserted      := v_inserted + 1;

        RAISE NOTICE '  -> waiter_id=%, orders=%, revenue=%, perf=%',
            rec.waiter_id, rec.nb_orders, rec.total_revenue, v_perf;
    END LOOP;

    -- ---------- 4. Sanity check: nothing found -> raise exception ----------
    IF v_inserted = 0 THEN
        RAISE EXCEPTION 'No order found for %-%. No report generated.',
                        p_year, p_month
            USING ERRCODE = 'P0002';
    END IF;

    RAISE NOTICE '=== Report %-% done: % waiters, % orders, total revenue = % ===',
        p_year, p_month, v_inserted, v_total_orders, v_total_revenue;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'generate_monthly_waiter_report: ERROR % - %', SQLSTATE, SQLERRM;
        RAISE;
END;
$$;

COMMENT ON PROCEDURE generate_monthly_waiter_report(INT, INT)
IS 'P2 - Computes and persists monthly per-waiter KPIs into MONTHLY_WAITER_REPORT, classifying each waiter (LOW/MEDIUM/HIGH).';
