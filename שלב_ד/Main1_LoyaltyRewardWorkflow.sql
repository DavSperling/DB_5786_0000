-- ============================================================
-- Stage 4 - MAIN PROGRAM 1
-- Name       : Main1_LoyaltyRewardWorkflow.sql
-- Scenario   : The restaurant wants to reward its top Gold
--              customers: list them via the function
--              get_top_loyalty_customers (F1), then apply an
--              extra discount to all of their in-progress
--              bills via apply_loyalty_tier_discount (P1).
-- Showcases  :
--   * Calling a FUNCTION returning a REF CURSOR.
--   * Reading the REF CURSOR from the main block.
--   * Calling a PROCEDURE that mutates the database.
--   * BEFORE / AFTER state inspection on BILL.
-- ============================================================

-- =========================================================
-- 0. Initial state (BEFORE)
-- =========================================================
\echo '======= BEFORE: Gold In Progress bills ======='
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

\echo '======= BEFORE: loyalty_transaction & audit counters ======='
SELECT (SELECT COUNT(*) FROM loyalty_transaction) AS tx_count_before,
       (SELECT COUNT(*) FROM loyalty_audit_log)   AS audit_count_before;


-- =========================================================
-- 1. Call FUNCTION F1 - read the REF CURSOR
-- =========================================================
\echo '======= CALL F1: get_top_loyalty_customers(Gold, 0) ======='
BEGIN;

    -- F1 opens the cursor in the current transaction
    SELECT get_top_loyalty_customers('Gold', 0, 'cur_main1');

    -- Consume the REF CURSOR
    FETCH ALL IN cur_main1;

    CLOSE cur_main1;

COMMIT;


-- =========================================================
-- 2. Call PROCEDURE P1 (DML)
--    Apply +5% discount to all Gold In Progress bills.
-- =========================================================
\echo '======= CALL P1: apply_loyalty_tier_discount(Gold, 5) ======='
CALL apply_loyalty_tier_discount('Gold', 5);


-- =========================================================
-- 3. Final state (AFTER)
-- =========================================================
\echo '======= AFTER: same bills, with new discounts ======='
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

\echo '======= AFTER: loyalty_transaction & audit counters ======='
SELECT (SELECT COUNT(*) FROM loyalty_transaction) AS tx_count_after,
       (SELECT COUNT(*) FROM loyalty_audit_log)   AS audit_count_after;


-- =========================================================
-- 4. EXCEPTION DEMO
--    Invalid tier -> F1 must raise an exception.
-- =========================================================
\echo '======= EXCEPTION DEMO: invalid tier ======='
DO $$
BEGIN
    PERFORM get_top_loyalty_customers('VIP', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Exception caught as expected: %', SQLERRM;
END;
$$;
