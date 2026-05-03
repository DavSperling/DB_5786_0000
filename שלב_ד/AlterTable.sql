-- ============================================================
-- שלב ד - ALTER TABLE
-- Toutes les modifications de schéma effectuées pour rendre
-- les fonctions / procédures / triggers de l'étape 4 plus
-- intéressants et cohérents.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Table de log MONTHLY_WAITER_REPORT
--    Utilisée par la procédure P2 (generate_monthly_waiter_report)
--    pour persister les KPI mensuels de chaque serveur.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS MONTHLY_WAITER_REPORT CASCADE;

CREATE TABLE MONTHLY_WAITER_REPORT (
    report_id      SERIAL       PRIMARY KEY,
    report_year    INT          NOT NULL CHECK (report_year BETWEEN 2000 AND 2100),
    report_month   INT          NOT NULL CHECK (report_month BETWEEN 1 AND 12),
    waiter_id      INT          NOT NULL,
    nb_orders      INT          NOT NULL DEFAULT 0,
    total_revenue  NUMERIC(12,2) NOT NULL DEFAULT 0,
    avg_bill       NUMERIC(12,2) NOT NULL DEFAULT 0,
    perf_level     VARCHAR(10)  NOT NULL CHECK (perf_level IN ('LOW','MEDIUM','HIGH')),
    generated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_monthly_waiter UNIQUE (report_year, report_month, waiter_id)
);

COMMENT ON TABLE MONTHLY_WAITER_REPORT
IS 'Rapport mensuel des performances par serveur, alimenté par la procédure P2.';


-- ------------------------------------------------------------
-- 2. Table de log LOYALTY_AUDIT_LOG
--    Utilisée par le trigger T2 (award_loyalty_points_on_bill_update)
--    pour tracer chaque attribution automatique de points fidélité.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS LOYALTY_AUDIT_LOG CASCADE;

CREATE TABLE LOYALTY_AUDIT_LOG (
    log_id         SERIAL       PRIMARY KEY,
    bill_id        INT          NOT NULL,
    customer_id    INT,
    points_awarded INT          NOT NULL,
    old_amount     NUMERIC(10,2),
    new_amount     NUMERIC(10,2),
    logged_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE LOYALTY_AUDIT_LOG
IS 'Journal d''audit du trigger T2 : trace chaque ajout automatique de points fidélité après mise à jour d''une facture.';


-- ------------------------------------------------------------
-- 3. Vérifications post-ALTER
-- ------------------------------------------------------------
SELECT 'monthly_waiter_report' AS new_table, COUNT(*) AS rows FROM MONTHLY_WAITER_REPORT
UNION ALL
SELECT 'loyalty_audit_log',                  COUNT(*)        FROM LOYALTY_AUDIT_LOG;
