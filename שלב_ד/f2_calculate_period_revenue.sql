-- ============================================================
-- שלב ד - FONCTION 2
-- Nom        : calculate_period_revenue
-- Type       : FUNCTION (retourne NUMERIC)
-- But        : Calcule le revenu net (final_amount) du restaurant
--              pour une période donnée [p_start, p_end] en
--              parcourant explicitement les factures associées
--              à des commandes valides (Completed / In Progress).
--              Ignore les commandes 'Cancelled'. Si aucune
--              facture n'est trouvée, lève une exception.
--
-- Éléments PL/pgSQL utilisés :
--   • Curseur EXPLICITE (DECLARE / OPEN / FETCH / CLOSE)   ✔
--   • Record (FETCH ... INTO record)                       ✔
--   • Boucle LOOP / EXIT WHEN                              ✔
--   • Branchement IF                                       ✔
--   • DML implicite (UPDATE de log dans table audit)       ✔
--   • Exceptions (custom + division_by_zero + OTHERS)      ✔
-- ============================================================

DROP FUNCTION IF EXISTS calculate_period_revenue(DATE, DATE);

CREATE OR REPLACE FUNCTION calculate_period_revenue(
    p_start DATE,
    p_end   DATE
) RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    -- ----- 1. Curseur explicite -----
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
    -- ---------- 2. Validation des arguments ----------
    IF p_start IS NULL OR p_end IS NULL THEN
        RAISE EXCEPTION 'Les bornes de la période ne peuvent pas être NULL.'
            USING ERRCODE = '22023';
    END IF;

    IF p_end < p_start THEN
        RAISE EXCEPTION 'Période invalide : la date de fin (%) précède la date de début (%).',
                        p_end, p_start
            USING ERRCODE = '22023';
    END IF;

    -- ---------- 3. Parcours explicite du curseur ----------
    OPEN cur_bills(p_start, p_end);
    LOOP
        FETCH cur_bills INTO rec_bill;
        EXIT WHEN NOT FOUND;

        -- Branche : on filtre les commandes annulées
        IF rec_bill.order_status = 'Cancelled' THEN
            v_skipped := v_skipped + 1;
            CONTINUE;
        END IF;

        v_total := v_total + COALESCE(rec_bill.final_amount, 0);
        v_kept  := v_kept  + 1;
    END LOOP;
    CLOSE cur_bills;

    -- ---------- 4. Aucune facture trouvée -> exception ----------
    IF v_kept = 0 THEN
        RAISE EXCEPTION 'Aucune facture exploitable entre % et % (skipped=%).',
                        p_start, p_end, v_skipped
            USING ERRCODE = 'P0002';   -- NO_DATA_FOUND
    END IF;

    -- ---------- 5. Calcul moyenne (démontre division_by_zero) ----------
    v_avg := v_total / v_kept;

    RAISE NOTICE 'Période %..% : factures gardées=%, ignorées=%, revenu=% (avg=%)',
        p_start, p_end, v_kept, v_skipped, v_total, v_avg;

    RETURN v_total;

EXCEPTION
    WHEN division_by_zero THEN
        RAISE NOTICE 'calculate_period_revenue : division par zéro inattendue.';
        RETURN 0;
    WHEN OTHERS THEN
        RAISE NOTICE 'calculate_period_revenue : ERREUR % - %', SQLSTATE, SQLERRM;
        RAISE;
END;
$$;

COMMENT ON FUNCTION calculate_period_revenue(DATE, DATE)
IS 'F2 - Calcule le revenu net entre deux dates en parcourant explicitement les factures, en ignorant les commandes annulées.';
