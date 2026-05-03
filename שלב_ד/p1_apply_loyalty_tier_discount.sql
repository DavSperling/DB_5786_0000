-- ============================================================
-- שלב ד - PROCÉDURE 1
-- Nom        : apply_loyalty_tier_discount
-- Type       : PROCEDURE
-- But        : Pour tous les clients d'un tier donné, applique
--              une remise supplémentaire (en %) à TOUTES leurs
--              factures dont la commande est encore 'In Progress'.
--              La remise est plafonnée selon le tier (CASE) :
--                 Bronze   -> max 10%
--                 Silver   -> max 15%
--                 Gold     -> max 20%
--                 Platinum -> max 30%
--              Pour chaque facture mise à jour, on insère AUSSI
--              une transaction de fidélité dans loyalty_transaction
--              (= 2 instructions DML, requirement DML respecté).
--              Toutes les modifs sont faites dans une boucle qui
--              parcourt EXPLICITEMENT un curseur (DECLARE/OPEN).
--
-- Éléments PL/pgSQL utilisés :
--   • Curseur EXPLICITE                              ✔
--   • Record (FETCH INTO)                            ✔
--   • Boucle LOOP                                    ✔
--   • Branchement CASE + IF                          ✔
--   • DML : UPDATE bill (2 colonnes)                 ✔
--   • DML : INSERT INTO loyalty_transaction          ✔
--   • Exception (raise_exception, OTHERS)            ✔
-- ============================================================

DROP PROCEDURE IF EXISTS apply_loyalty_tier_discount(VARCHAR, NUMERIC);

CREATE OR REPLACE PROCEDURE apply_loyalty_tier_discount(
    p_tier      VARCHAR,
    p_extra_pct NUMERIC          -- exprimé en pourcentage, ex 5 pour 5%
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- ---- Curseur explicite : factures éligibles + tier client ----
    cur_eligible CURSOR (tier_filter VARCHAR) FOR
        SELECT b.bill_id,
               b.total_amount,
               b.discount_amount,
               b.final_amount,
               c.customer_id,
               l.loyalty_id,
               lt.level                AS tier_level
          FROM bill            b
          JOIN "ORDER"         o  ON b.order_id    = o.order_id
          JOIN customer        c  ON o.customer_id = c.customer_id
          JOIN loyalty         l  ON c.customer_id = l.customer_id
          JOIN loyalty_tier    lt ON l.tier_id     = lt.tier_id
         WHERE lt.level     = tier_filter
           AND o.order_status = 'In Progress'
         FOR UPDATE OF b;

    rec               RECORD;
    v_max_pct         NUMERIC(5,2);
    v_applied_pct     NUMERIC(5,2);
    v_extra_amount    NUMERIC(10,2);
    v_new_discount    NUMERIC(10,2);
    v_new_final       NUMERIC(10,2);
    v_count           INT := 0;
    v_default_reason  INT;
BEGIN
    -- ---------- 1. Validation des entrées ----------
    IF p_tier NOT IN ('Bronze','Silver','Gold','Platinum') THEN
        RAISE EXCEPTION 'Tier invalide "%".', p_tier
            USING ERRCODE = '22023';
    END IF;

    IF p_extra_pct IS NULL OR p_extra_pct < 0 OR p_extra_pct > 100 THEN
        RAISE EXCEPTION 'Pourcentage invalide (reçu : %). Attendu entre 0 et 100.',
                        p_extra_pct
            USING ERRCODE = '22023';
    END IF;

    -- ---------- 2. Plafond par tier (CASE) ----------
    v_max_pct := CASE p_tier
                     WHEN 'Bronze'   THEN 10
                     WHEN 'Silver'   THEN 15
                     WHEN 'Gold'     THEN 20
                     WHEN 'Platinum' THEN 30
                 END;

    v_applied_pct := LEAST(p_extra_pct, v_max_pct);

    IF v_applied_pct < p_extra_pct THEN
        RAISE NOTICE 'Pourcentage demandé (%) plafonné à % pour le tier %.',
                     p_extra_pct, v_applied_pct, p_tier;
    END IF;

    -- ---------- 3. Trouver une raison existante pour les transactions de fidélité ----------
    SELECT reason_id
      INTO v_default_reason
      FROM reason
     ORDER BY reason_id
     LIMIT 1;

    IF v_default_reason IS NULL THEN
        RAISE EXCEPTION 'Aucune entrée dans la table "reason" : impossible d''insérer dans loyalty_transaction.'
            USING ERRCODE = 'P0002';
    END IF;

    -- ---------- 4. Boucle sur le curseur explicite ----------
    OPEN cur_eligible(p_tier);
    LOOP
        FETCH cur_eligible INTO rec;
        EXIT WHEN NOT FOUND;

        -- Calculs
        v_extra_amount := ROUND(rec.total_amount * v_applied_pct / 100, 2);
        v_new_discount := COALESCE(rec.discount_amount, 0) + v_extra_amount;
        v_new_final    := GREATEST(rec.total_amount - v_new_discount, 0);

        -- DML #1 : UPDATE bill
        UPDATE bill
           SET discount_amount = v_new_discount,
               final_amount    = v_new_final
         WHERE bill_id = rec.bill_id;

        -- DML #2 : INSERT loyalty_transaction (1 point fidélité offert pour chaque euro de remise)
        INSERT INTO loyalty_transaction (
            transaction_id, points_change, created_at, loyalty_id, reason_id
        )
        VALUES (
            (SELECT COALESCE(MAX(transaction_id), 0) + 1 FROM loyalty_transaction),
            CEIL(v_extra_amount)::INT,
            CURRENT_DATE,
            rec.loyalty_id,
            v_default_reason
        );

        v_count := v_count + 1;
    END LOOP;
    CLOSE cur_eligible;

    RAISE NOTICE 'apply_loyalty_tier_discount : tier=%, pct_applique=%, factures_mises_a_jour=%',
                 p_tier, v_applied_pct, v_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'apply_loyalty_tier_discount : ERREUR % - %', SQLSTATE, SQLERRM;
        RAISE;
END;
$$;

COMMENT ON PROCEDURE apply_loyalty_tier_discount(VARCHAR, NUMERIC)
IS 'P1 - Applique une remise supplémentaire (plafonnée par tier) aux factures en cours des clients du tier indiqué, et crédite des points fidélité associés.';
