-- ============================================================
-- Stage 3 - VIEWS
-- 3 views for the integrated database:
--   * View 1: ORDERS & BILLING perspective (our department)
--   * View 2: CUSTOMER / LOYALTY perspective (imported department)
--   * View 3: integrated cross-department view
-- Each view is followed by 2 meaningful analytical queries.
-- ============================================================

-- Idempotent cleanup (allows replaying the script)
DROP VIEW IF EXISTS Customer_Cross_Activity;
DROP VIEW IF EXISTS Customer_Loyalty_Status;
DROP VIEW IF EXISTS Customer_Order_Summary;


-- =====================================================================
-- VIEW 1 (ORDERS & BILLING): Customer_Order_Summary
-- ---------------------------------------------------------------------
-- For each customer, aggregates their commercial activity:
-- number of orders, total billed, average bill, last order timestamp.
-- Combines 3 tables: customer + "ORDER" + bill.
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

-- View preview (first 10 rows)
SELECT * FROM Customer_Order_Summary ORDER BY customer_id LIMIT 10;


-- ---- View 1 - Query 1: Top 10 customers by revenue ----
-- PURPOSE: identify the highest-value customers to target VIP
--          programs or premium offers.
SELECT customer_name, total_orders, total_spent, last_order_time
FROM   Customer_Order_Summary
WHERE  total_orders > 0
ORDER BY total_spent DESC
LIMIT 10;


-- ---- View 1 - Query 2: Inactive customers (never ordered) ----
-- PURPOSE: spot customers who registered but never converted to a
--          purchase, for targeted marketing.
SELECT customer_id, customer_name, email
FROM   Customer_Order_Summary
WHERE  total_orders = 0
ORDER BY customer_id
LIMIT 10;


-- =====================================================================
-- VIEW 2 (CUSTOMER / LOYALTY): Customer_Loyalty_Status
-- ---------------------------------------------------------------------
-- For each customer, exposes their current loyalty status:
-- tier (Bronze/Silver/Gold/Platinum), points, number of loyalty
-- transactions and number of past reservations.
-- Combines 4 tables: customer + loyalty + loyalty_tier + reservation.
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

-- View preview (10 rows)
SELECT * FROM Customer_Loyalty_Status ORDER BY customer_id LIMIT 10;


-- ---- View 2 - Query 1: Distribution of customers by loyalty tier ----
-- PURPOSE: verify the balance of the loyalty program
--          (e.g. too many Bronze? not enough Platinum?).
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


-- ---- View 2 - Query 2: Top 10 most loyal customers ----
-- PURPOSE: reward highly-engaged customers (points + reservations).
SELECT customer_name, tier_level, current_points, total_reservations, last_reservation_date
FROM   Customer_Loyalty_Status
ORDER BY current_points DESC, total_reservations DESC
LIMIT 10;


-- =====================================================================
-- VIEW 3 (INTEGRATED): Customer_Cross_Activity
-- ---------------------------------------------------------------------
-- Crosses the ORDERS & BILLING activity with the
-- RESERVATIONS / LOYALTY activity to produce a 360-degree view
-- of every customer.
-- Combines 6 tables: customer + reservation + "ORDER" + bill + loyalty + loyalty_tier.
-- This view fully exploits the integration.
--
-- TECHNICAL NOTE: orders and reservations are pre-aggregated through
-- LATERAL subqueries to avoid the cartesian product that would inflate
-- total_revenue (each bill multiplied by the number of reservations).
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

-- View preview (10 rows)
SELECT * FROM Customer_Cross_Activity ORDER BY customer_id LIMIT 10;


-- ---- View 3 - Query 1: Customer distribution by engagement type ----
-- PURPOSE: measure the reservation-to-order conversion rate, and
--          identify segments to activate (e.g. reservation but no order).
SELECT engagement_type,
       COUNT(*)                              AS nb_customers,
       ROUND(AVG(total_revenue), 2)          AS avg_revenue,
       ROUND(AVG(nb_reservations), 1)        AS avg_reservations,
       ROUND(AVG(nb_orders), 1)              AS avg_orders
FROM   Customer_Cross_Activity
GROUP BY engagement_type
ORDER BY nb_customers DESC;


-- ---- View 3 - Query 2: Engagement and average revenue per loyalty tier ----
-- PURPOSE: check whether customers who both reserve and order are
--          better rewarded by the loyalty program (engagement-tier correlation).
SELECT tier_level,
       COUNT(*)                              AS nb_customers,
       ROUND(AVG(nb_reservations), 1)        AS avg_reservations,
       ROUND(AVG(nb_orders), 1)              AS avg_orders,
       ROUND(AVG(total_revenue), 2)          AS avg_revenue
FROM   Customer_Cross_Activity
GROUP BY tier_level
ORDER BY avg_revenue DESC;
