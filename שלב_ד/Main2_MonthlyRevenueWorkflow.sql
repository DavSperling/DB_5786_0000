-- ============================================================
-- שלב ד - PROGRAMME PRINCIPAL 2
-- Nom        : Main2_MonthlyRevenueWorkflow.sql
-- Scénario   : En fin de mois, le manager veut un rapport
--              global :
--                1. revenu total de la période (F2)
--                2. détail par serveur, persisté en base (P2)
-- Démontre   :
--   • Appel d'une FONCTION renvoyant un scalaire.
--   • Appel d'une PROCÉDURE qui fait des DML (DELETE + INSERT).
--   • Vérification du contenu de MONTHLY_WAITER_REPORT
--     avant / après.
--   • Démonstration d'EXCEPTION (période vide).
-- ============================================================

-- =========================================================
-- 0. Détecter une période qui contient effectivement des données
-- =========================================================
\echo '======= Détection de la période la plus active ======='
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
-- 1. État BEFORE de MONTHLY_WAITER_REPORT
-- =========================================================
\echo '======= BEFORE : contenu MONTHLY_WAITER_REPORT ======='
SELECT COUNT(*) AS nb_rows_before FROM MONTHLY_WAITER_REPORT;


-- =========================================================
-- 2. Appel de la FONCTION F2 (scalar)
--    Sur l'année 2024 entière (notre dataset principal).
-- =========================================================
\echo '======= APPEL F2 : calculate_period_revenue(2024-01-01, 2024-12-31) ======='
SELECT calculate_period_revenue(DATE '2024-01-01', DATE '2024-12-31') AS revenue_2024;


-- =========================================================
-- 3. Appel de la PROCÉDURE P2
--    On génère le rapport pour avril 2024 (mois bien rempli).
-- =========================================================
\echo '======= APPEL P2 : generate_monthly_waiter_report(2024, 4) ======='
CALL generate_monthly_waiter_report(2024, 4);


-- =========================================================
-- 4. État AFTER de MONTHLY_WAITER_REPORT
-- =========================================================
\echo '======= AFTER : contenu MONTHLY_WAITER_REPORT (top 10) ======='
SELECT report_year, report_month, waiter_id, nb_orders,
       total_revenue, avg_bill, perf_level, generated_at
  FROM MONTHLY_WAITER_REPORT
 WHERE report_year = 2024 AND report_month = 4
 ORDER BY total_revenue DESC
 LIMIT 10;

\echo '======= Distribution par perf_level ======='
SELECT perf_level, COUNT(*) AS nb_waiters,
       ROUND(AVG(total_revenue),2) AS avg_revenue
  FROM MONTHLY_WAITER_REPORT
 WHERE report_year = 2024 AND report_month = 4
 GROUP BY perf_level
 ORDER BY CASE perf_level
            WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END;


-- =========================================================
-- 5. Démo EXCEPTION : F2 sur une période vide
-- =========================================================
\echo '======= DÉMO EXCEPTION : période sans données ======='
DO $$
DECLARE v_rev NUMERIC;
BEGIN
    v_rev := calculate_period_revenue(DATE '1990-01-01', DATE '1990-12-31');
    RAISE NOTICE 'Revenu : %', v_rev;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception attrapée comme prévu : %', SQLERRM;
END;
$$;


-- =========================================================
-- 6. Démo EXCEPTION : P2 sur un mois sans données
-- =========================================================
\echo '======= DÉMO EXCEPTION : mois sans commandes ======='
DO $$
BEGIN
    CALL generate_monthly_waiter_report(1999, 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception attrapée comme prévu : %', SQLERRM;
END;
$$;
