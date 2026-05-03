-- ============================================================
-- Stage 4 - MAIN PROGRAM 2
-- Name       : Main2_MonthlyRevenueWorkflow.sql
-- Scenario   : At month-end, the manager wants a global report:
--                1. total revenue for the period (F2)
--                2. per-waiter detail, persisted (P2)
-- Showcases  :
--   * Calling a FUNCTION returning a scalar.
--   * Calling a PROCEDURE that performs DML (DELETE + INSERT).
--   * BEFORE / AFTER state of MONTHLY_WAITER_REPORT.
--   * EXCEPTION demo (empty period).
-- ============================================================

-- =========================================================
-- 0. Detect a period that actually contains data
-- =========================================================
\echo '======= Detect the busiest period ======='
WITH best_month AS (
    SELECT EXTRACT(YEAR  FROM o.order_time)::INT AS y,
           EXTRACT(MONTH FROM o.order_time)::INT AS m,
           COUNT(*) AS nb
      FROM "ORDER" o
     GROUP BY 1,2
     ORDER BY nb DESC
     LIMIT 1
)
SELECT * FROM best_month;


-- =========================================================
-- 1. BEFORE state of MONTHLY_WAITER_REPORT
-- =========================================================
\echo '======= BEFORE: MONTHLY_WAITER_REPORT contents ======='
SELECT COUNT(*) AS nb_rows_before FROM MONTHLY_WAITER_REPORT;


-- =========================================================
-- 2. Call FUNCTION F2 (scalar)
--    Full year 2024 (our main dataset).
-- =========================================================
\echo '======= CALL F2: calculate_period_revenue(2024-01-01, 2024-12-31) ======='
SELECT calculate_period_revenue(DATE '2024-01-01', DATE '2024-12-31') AS revenue_2024;


-- =========================================================
-- 3. Call PROCEDURE P2
--    Generate the report for April 2024 (busiest month).
-- =========================================================
\echo '======= CALL P2: generate_monthly_waiter_report(2024, 4) ======='
CALL generate_monthly_waiter_report(2024, 4);


-- =========================================================
-- 4. AFTER state of MONTHLY_WAITER_REPORT
-- =========================================================
\echo '======= AFTER: MONTHLY_WAITER_REPORT contents (top 10) ======='
SELECT report_year, report_month, waiter_id, nb_orders,
       total_revenue, avg_bill, perf_level, generated_at
  FROM MONTHLY_WAITER_REPORT
 WHERE report_year = 2024 AND report_month = 4
 ORDER BY total_revenue DESC
 LIMIT 10;

\echo '======= Distribution by perf_level ======='
SELECT perf_level, COUNT(*) AS nb_waiters,
       ROUND(AVG(total_revenue),2) AS avg_revenue
  FROM MONTHLY_WAITER_REPORT
 WHERE report_year = 2024 AND report_month = 4
 GROUP BY perf_level
 ORDER BY CASE perf_level
            WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END;


-- =========================================================
-- 5. EXCEPTION DEMO: F2 on an empty period
-- =========================================================
\echo '======= EXCEPTION DEMO: empty period ======='
DO $$
DECLARE v_rev NUMERIC;
BEGIN
    v_rev := calculate_period_revenue(DATE '1990-01-01', DATE '1990-12-31');
    RAISE NOTICE 'Revenue: %', v_rev;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught as expected: %', SQLERRM;
END;
$$;


-- =========================================================
-- 6. EXCEPTION DEMO: P2 on a month without orders
-- =========================================================
\echo '======= EXCEPTION DEMO: month with no orders ======='
DO $$
BEGIN
    CALL generate_monthly_waiter_report(1999, 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught as expected: %', SQLERRM;
END;
$$;
