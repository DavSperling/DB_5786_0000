-- ============================================================
-- שלב ד - PROGRAMME PRINCIPAL 1
-- Nom        : Main1_LoyaltyRewardWorkflow.sql
-- Scénario   : Le restaurant veut récompenser ses meilleurs
--              clients GOLD : on liste leur top via la fonction
--              get_top_loyalty_customers (F1) puis on applique
--              une remise supplémentaire à toutes leurs factures
--              en cours via apply_loyalty_tier_discount (P1).
-- Démontre   :
--   • Appel d'une FONCTION qui retourne un REF CURSOR.
--   • Lecture du REF CURSOR depuis le bloc principal.
--   • Appel d'une PROCÉDURE qui modifie la base.
--   • Vérification de l'état BEFORE / AFTER de BILL.
-- ============================================================

-- =========================================================
-- 0. État initial (BEFORE)
-- =========================================================
\echo '======= BEFORE : factures Gold In Progress ======='
SELECT b.bill_id, b.total_amount, b.discount_amount, b.final_amount,
       o.order_status, c.customer_id, c.first_name, lt.level
  FROM bill         b
  JOIN "ORDER"      o  ON b.order_id    = o.order_id
  JOIN customer     c  ON o.customer_id = c.customer_id
  JOIN loyalty      l  ON c.customer_id = l.customer_id
  JOIN loyalty_tier lt ON l.tier_id     = lt.tier_id
 WHERE lt.level = 'Gold'
   AND o.order_status = 'In Progress'
 ORDER BY b.bill_id
 LIMIT 10;

\echo '======= BEFORE : nombre de loyalty_transaction et lignes audit ======='
SELECT (SELECT COUNT(*) FROM loyalty_transaction) AS tx_count_before,
       (SELECT COUNT(*) FROM loyalty_audit_log)   AS audit_count_before;


-- =========================================================
-- 1. Appel de la FONCTION F1 - on lit le REF CURSOR
-- =========================================================
\echo '======= APPEL F1 : get_top_loyalty_customers(Gold, 0) ======='
BEGIN;

    -- F1 ouvre le curseur dans la transaction courante
    SELECT get_top_loyalty_customers('Gold', 0, 'cur_main1');

    -- On consomme le REF CURSOR (10 premières lignes)
    FETCH ALL IN cur_main1;

    CLOSE cur_main1;

COMMIT;


-- =========================================================
-- 2. Appel de la PROCÉDURE P1 (DML)
--    On applique +5% de remise à tous les Gold In Progress.
-- =========================================================
\echo '======= APPEL P1 : apply_loyalty_tier_discount(Gold, 5) ======='
CALL apply_loyalty_tier_discount('Gold', 5);


-- =========================================================
-- 3. État final (AFTER)
-- =========================================================
\echo '======= AFTER : mêmes factures, on voit les remises ======='
SELECT b.bill_id, b.total_amount, b.discount_amount, b.final_amount,
       o.order_status, c.customer_id, c.first_name, lt.level
  FROM bill         b
  JOIN "ORDER"      o  ON b.order_id    = o.order_id
  JOIN customer     c  ON o.customer_id = c.customer_id
  JOIN loyalty      l  ON c.customer_id = l.customer_id
  JOIN loyalty_tier lt ON l.tier_id     = lt.tier_id
 WHERE lt.level = 'Gold'
   AND o.order_status = 'In Progress'
 ORDER BY b.bill_id
 LIMIT 10;

\echo '======= AFTER : compteurs loyalty_transaction et audit ======='
SELECT (SELECT COUNT(*) FROM loyalty_transaction) AS tx_count_after,
       (SELECT COUNT(*) FROM loyalty_audit_log)   AS audit_count_after;


-- =========================================================
-- 4. Démo de gestion d'EXCEPTION
--    Tier invalide -> F1 doit lever une exception.
-- =========================================================
\echo '======= DÉMO EXCEPTION : tier invalide ======='
DO $$
BEGIN
    PERFORM get_top_loyalty_customers('VIP', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception attrapée comme prévu : %', SQLERRM;
END;
$$;
