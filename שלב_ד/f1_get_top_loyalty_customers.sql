-- ============================================================
-- שלב ד - FONCTION 1
-- Nom        : get_top_loyalty_customers
-- Type       : FUNCTION (retourne un REF CURSOR)
-- But        : Pour un tier de fidélité donné (Bronze/Silver/
--              Gold/Platinum) et un nombre minimal de commandes,
--              renvoie un curseur contenant les clients qui
--              correspondent, classés par revenu décroissant,
--              avec une catégorie de récompense calculée.
--
-- Éléments PL/pgSQL utilisés :
--   • RETURN refcursor                              ✔
--   • Curseur EXPLICITE (FOR rec IN cur LOOP)       ✔
--   • Record (%ROWTYPE-like via RECORD)             ✔
--   • Branchement IF / CASE                         ✔
--   • Boucle                                        ✔
--   • Exception (NO_DATA_FOUND, OTHERS, custom)     ✔
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
    -- ---------- 1. Validation des arguments ----------
    IF p_tier NOT IN ('Bronze','Silver','Gold','Platinum') THEN
        RAISE EXCEPTION
            'Tier invalide "%". Valeurs autorisées : Bronze, Silver, Gold, Platinum.',
            p_tier
            USING ERRCODE = '22023';
    END IF;

    IF p_min_orders < 0 THEN
        RAISE EXCEPTION 'Le nombre minimal de commandes doit être >= 0 (reçu : %).',
            p_min_orders
            USING ERRCODE = '22023';
    END IF;

    -- ---------- 2. Vérifier qu'il existe au moins un client matching ----------
    SELECT COUNT(*)
      INTO v_count
      FROM customer            c
      JOIN loyalty             l  ON c.customer_id = l.customer_id
      JOIN loyalty_tier        lt ON l.tier_id     = lt.tier_id
      WHERE lt.level = p_tier;

    IF v_count = 0 THEN
        RAISE EXCEPTION 'Aucun client trouvé pour le tier "%".', p_tier
            USING ERRCODE = 'P0002';   -- équivalent NO_DATA_FOUND
    END IF;

    -- ---------- 3. Ouvrir le REF CURSOR ----------
    -- Sélection enrichie d'une catégorie de récompense calculée par CASE.
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

    RAISE NOTICE 'Curseur "%" ouvert : tier=% / min_orders=% / clients_dispo=%',
                 p_cursor, p_tier, p_min_orders, v_count;

    RETURN p_cursor;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'get_top_loyalty_customers : ERREUR % - %',
            SQLSTATE, SQLERRM;
        RAISE;       -- on relance pour signaler l'échec à l'appelant
END;
$$;

COMMENT ON FUNCTION get_top_loyalty_customers(VARCHAR, INT, REFCURSOR)
IS 'F1 - Retourne un REF CURSOR sur les meilleurs clients d''un tier de fidélité, classés par revenu, avec une catégorie de récompense calculée.';
