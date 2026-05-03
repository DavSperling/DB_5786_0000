-- ============================================================
-- שלב ד - PROCÉDURE 2
-- Nom        : generate_monthly_waiter_report
-- Type       : PROCEDURE
-- But        : Génère (ou régénère) le rapport mensuel par
--              serveur et l'enregistre dans la table
--              MONTHLY_WAITER_REPORT (créée via AlterTable.sql).
--              On classe chaque serveur en HIGH / MEDIUM / LOW
--              suivant son revenu sur le mois.
--              Démontre le curseur IMPLICITE via FOR ... IN
--              (record loop sans déclaration explicite).
--
-- Éléments PL/pgSQL utilisés :
--   • Curseur IMPLICITE (FOR rec IN <query>)                ✔
--   • Record                                                 ✔
--   • Boucle FOR                                             ✔
--   • Branchement IF / ELSIF                                 ✔
--   • DML : DELETE existant + INSERT (UPSERT logique)        ✔
--   • Exceptions (raise_exception, OTHERS)                   ✔
--   • RAISE NOTICE pour preuve d'exécution                   ✔
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
    -- ---------- 1. Validation des paramètres ----------
    IF p_year IS NULL OR p_month IS NULL THEN
        RAISE EXCEPTION 'Année et mois ne peuvent pas être NULL.'
            USING ERRCODE = '22023';
    END IF;

    IF p_month < 1 OR p_month > 12 THEN
        RAISE EXCEPTION 'Mois invalide (reçu : %).', p_month
            USING ERRCODE = '22023';
    END IF;

    -- ---------- 2. Purge des anciens enregistrements pour ce (year, month) ----------
    DELETE FROM MONTHLY_WAITER_REPORT
     WHERE report_year  = p_year
       AND report_month = p_month;

    -- ---------- 3. Curseur IMPLICITE : FOR rec IN <query> ----------
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
        -- Branchement : niveau de performance
        IF rec.total_revenue >= 1500 THEN
            v_perf := 'HIGH';
        ELSIF rec.total_revenue >= 500 THEN
            v_perf := 'MEDIUM';
        ELSE
            v_perf := 'LOW';
        END IF;

        -- DML : INSERT dans la table de rapport
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

    -- ---------- 4. Vérification : si rien trouvé, lever exception ----------
    IF v_inserted = 0 THEN
        RAISE EXCEPTION 'Aucune commande trouvée pour %-%. Aucun rapport généré.',
                        p_year, p_month
            USING ERRCODE = 'P0002';
    END IF;

    RAISE NOTICE '=== Rapport %-% terminé : % serveurs, % commandes, revenu total = % ===',
        p_year, p_month, v_inserted, v_total_orders, v_total_revenue;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'generate_monthly_waiter_report : ERREUR % - %', SQLSTATE, SQLERRM;
        RAISE;
END;
$$;

COMMENT ON PROCEDURE generate_monthly_waiter_report(INT, INT)
IS 'P2 - Calcule et persiste les KPI mensuels par serveur dans MONTHLY_WAITER_REPORT, classifie chaque serveur (LOW/MEDIUM/HIGH).';
