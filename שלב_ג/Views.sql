-- ============================================================
-- שלב ג - VIEWS
-- 3 vues pour la base intégrée :
--   • View 1 : point de vue ORDERS & BILLING (votre département)
--   • View 2 : point de vue CUSTOMER / LOYALTY (département importé)
--   • View 3 : vue intégrée croisant les 2 départements
-- Chaque vue est suivie de 2 requêtes analytiques significatives.
-- ============================================================

-- Nettoyage idempotent (permet de relancer le script)
DROP VIEW IF EXISTS Customer_Cross_Activity;
DROP VIEW IF EXISTS Customer_Loyalty_Status;
DROP VIEW IF EXISTS Customer_Order_Summary;


-- =====================================================================
-- VIEW 1 (ORDERS & BILLING) : Customer_Order_Summary
-- ---------------------------------------------------------------------
-- Pour chaque client, agrège son activité commerciale :
-- nombre de commandes, total facturé, montant moyen par commande,
-- date de la dernière commande.
-- Combine 3 tables : customer + "ORDER" + bill.
-- =====================================================================
CREATE VIEW Customer_Order_Summary AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    COUNT(DISTINCT o.order_id)               AS total_orders,
    COALESCE(SUM(b.final_amount), 0)         AS total_spent,
    COALESCE(ROUND(AVG(b.final_amount), 2), 0) AS avg_bill_amount,
    MAX(o.order_time)                        AS last_order_time
FROM       customer c
LEFT JOIN  "ORDER" o ON c.customer_id = o.customer_id
LEFT JOIN  bill    b ON o.order_id    = b.order_id
GROUP BY   c.customer_id, c.first_name, c.last_name, c.email;

-- Aperçu de la vue (10 lignes max)
SELECT * FROM Customer_Order_Summary ORDER BY customer_id LIMIT 10;


-- ---- View 1 - Query 1 : Top 10 des clients par chiffre d'affaires ----
-- BUT : identifier les clients à plus forte valeur pour cibler des
--       programmes VIP ou des offres premium.
SELECT customer_name, total_orders, total_spent, last_order_time
FROM   Customer_Order_Summary
WHERE  total_orders > 0
ORDER BY total_spent DESC
LIMIT 10;


-- ---- View 1 - Query 2 : Clients inactifs (jamais commandé) ----
-- BUT : repérer les clients qui ne sont jamais passés à l'achat malgré
--       leur inscription, pour des actions marketing ciblées.
SELECT customer_id, customer_name, email
FROM   Customer_Order_Summary
WHERE  total_orders = 0
ORDER BY customer_id
LIMIT 10;


-- =====================================================================
-- VIEW 2 (CUSTOMER / LOYALTY) : Customer_Loyalty_Status
-- ---------------------------------------------------------------------
-- Pour chaque client, donne son statut fidélité actuel :
-- tier (Bronze/Silver/Gold/Platinum), points, nombre de transactions
-- de fidélité et nombre de réservations passées.
-- Combine 4 tables : customer + loyalty + loyalty_tier + reservation.
-- =====================================================================
CREATE VIEW Customer_Loyalty_Status AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    COALESCE(lt.level, 'No Loyalty')             AS tier_level,
    COALESCE(l.points, 0)                        AS current_points,
    COUNT(DISTINCT lx.transaction_id)            AS loyalty_tx_count,
    COUNT(DISTINCT r.reservation_id)             AS total_reservations,
    MAX(r.datetime)                              AS last_reservation_date
FROM        customer c
LEFT JOIN   loyalty             l  ON c.customer_id = l.customer_id
LEFT JOIN   loyalty_tier        lt ON l.tier_id     = lt.tier_id
LEFT JOIN   loyalty_transaction lx ON l.loyalty_id  = lx.loyalty_id
LEFT JOIN   reservation         r  ON c.customer_id = r.customer_id
GROUP BY    c.customer_id, c.first_name, c.last_name, lt.level, l.points;

-- Aperçu de la vue (10 lignes)
SELECT * FROM Customer_Loyalty_Status ORDER BY customer_id LIMIT 10;


-- ---- View 2 - Query 1 : Distribution des clients par tier de fidélité ----
-- BUT : voir si le programme de fidélité atteint sa cible
--       (ex. trop de Bronze ? pas assez de Platinum ?).
SELECT tier_level,
       COUNT(*)                              AS nb_customers,
       ROUND(AVG(current_points), 0)         AS avg_points,
       ROUND(AVG(total_reservations), 1)     AS avg_reservations
FROM   Customer_Loyalty_Status
GROUP BY tier_level
ORDER BY
    CASE tier_level
        WHEN 'Bronze'   THEN 1
        WHEN 'Silver'   THEN 2
        WHEN 'Gold'     THEN 3
        WHEN 'Platinum' THEN 4
        ELSE 5
    END;


-- ---- View 2 - Query 2 : Top 10 clients les plus fidèles ----
-- BUT : récompenser les clients à fort engagement (points + réservations).
SELECT customer_name, tier_level, current_points, total_reservations, last_reservation_date
FROM   Customer_Loyalty_Status
ORDER BY current_points DESC, total_reservations DESC
LIMIT 10;


-- =====================================================================
-- VIEW 3 (INTÉGRÉE) : Customer_Cross_Activity
-- ---------------------------------------------------------------------
-- Croise l'activité côté ORDERS & BILLING avec l'activité côté
-- RESERVATIONS / LOYALTY pour produire une vision 360° du client.
-- Combine 6 tables : customer + reservation + "ORDER" + bill + loyalty + loyalty_tier.
-- C'est cette vue qui exploite pleinement l'intégration.
--
-- NOTE TECHNIQUE : on pré-agrège commandes et réservations dans des
-- sous-requêtes LATERAL pour éviter le produit cartésien qui ferait
-- exploser le total_revenue (chaque bill multiplié par nb réservations).
-- =====================================================================
CREATE VIEW Customer_Cross_Activity AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name              AS customer_name,
    COALESCE(lt.level, 'No Loyalty')                AS tier_level,
    res.nb_reservations,
    ord.nb_orders,
    ord.total_revenue,
    CASE
        WHEN ord.nb_orders   = 0 AND res.nb_reservations > 0 THEN 'Reservation only'
        WHEN ord.nb_orders   > 0 AND res.nb_reservations = 0 THEN 'Order only'
        WHEN ord.nb_orders   > 0 AND res.nb_reservations > 0 THEN 'Both'
        ELSE 'Inactive'
    END                                             AS engagement_type
FROM        customer c
LEFT JOIN   loyalty      l  ON c.customer_id = l.customer_id
LEFT JOIN   loyalty_tier lt ON l.tier_id     = lt.tier_id
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS nb_reservations
    FROM   reservation r
    WHERE  r.customer_id = c.customer_id
) res ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)                       AS nb_orders,
           COALESCE(SUM(b.final_amount),0) AS total_revenue
    FROM   "ORDER" o
    LEFT JOIN bill b ON o.order_id = b.order_id
    WHERE  o.customer_id = c.customer_id
) ord ON TRUE;

-- Aperçu de la vue (10 lignes)
SELECT * FROM Customer_Cross_Activity ORDER BY customer_id LIMIT 10;


-- ---- View 3 - Query 1 : Répartition des clients par type d'engagement ----
-- BUT : mesurer la conversion réservation → commande, et identifier les
--       segments à activer (réservation sans commande, etc.).
SELECT engagement_type,
       COUNT(*)                              AS nb_customers,
       ROUND(AVG(total_revenue), 2)          AS avg_revenue,
       ROUND(AVG(nb_reservations), 1)        AS avg_reservations,
       ROUND(AVG(nb_orders), 1)              AS avg_orders
FROM   Customer_Cross_Activity
GROUP BY engagement_type
ORDER BY nb_customers DESC;


-- ---- View 3 - Query 2 : Tier moyen des clients selon leur activité ----
-- BUT : vérifier si les clients qui réservent ET commandent sont mieux
--       récompensés par le programme de fidélité (corrélation engagement / tier).
SELECT tier_level,
       COUNT(*)                              AS nb_customers,
       ROUND(AVG(nb_reservations), 1)        AS avg_reservations,
       ROUND(AVG(nb_orders), 1)              AS avg_orders,
       ROUND(AVG(total_revenue), 2)          AS avg_revenue
FROM   Customer_Cross_Activity
GROUP BY tier_level
ORDER BY avg_revenue DESC;
