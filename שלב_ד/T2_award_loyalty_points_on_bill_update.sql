-- ============================================================
-- Stage 4 - TRIGGER 2  (on UPDATE - course requirement)
-- Name       : trg_award_loyalty_points_on_bill_update
-- Fires      : AFTER UPDATE ON BILL
-- Purpose    : When the final_amount of a bill changes
--              (re-adjustment, discount applied, correction),
--              the linked customer is automatically rewarded:
--              1 loyalty point per 10 € slice of the new bill,
--              traced in loyalty_audit_log.
--
-- PL/pgSQL elements used:
--   * Implicit cursor (SELECT ... INTO record)           [x]
--   * Record                                             [x]
--   * Branching IF                                       [x]
--   * DML: UPDATE loyalty                                [x]
--   * DML: INSERT loyalty_transaction                    [x]
--   * DML: INSERT loyalty_audit_log                      [x]
--   * Exception (NO_DATA_FOUND, OTHERS)                  [x]
-- ============================================================

DROP TRIGGER  IF EXISTS trg_award_loyalty_points_on_bill_update ON BILL;
DROP FUNCTION IF EXISTS fn_award_loyalty_points_on_bill_update();

CREATE OR REPLACE FUNCTION fn_award_loyalty_points_on_bill_update()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    rec_link        RECORD;
    v_points        INT;
    v_default_reason INT;
BEGIN
    -- 1. Only react if final_amount actually changed
    IF NEW.final_amount IS NOT DISTINCT FROM OLD.final_amount THEN
        RETURN NEW;
    END IF;

    -- 2. Find the customer linked to the order -> bill
    SELECT o.customer_id, l.loyalty_id
      INTO rec_link
      FROM "ORDER"  o
      LEFT JOIN loyalty l ON l.customer_id = o.customer_id
     WHERE o.order_id = NEW.order_id;

    -- No customer OR no loyalty record -> do not reward
    IF NOT FOUND OR rec_link.customer_id IS NULL OR rec_link.loyalty_id IS NULL THEN
        INSERT INTO loyalty_audit_log(bill_id, customer_id, points_awarded, old_amount, new_amount)
        VALUES (NEW.bill_id, rec_link.customer_id, 0, OLD.final_amount, NEW.final_amount);
        RETURN NEW;
    END IF;

    -- 3. Compute points: 1 point per 10 € of the NEW bill
    v_points := GREATEST(FLOOR(NEW.final_amount / 10)::INT, 0);

    IF v_points = 0 THEN
        INSERT INTO loyalty_audit_log(bill_id, customer_id, points_awarded, old_amount, new_amount)
        VALUES (NEW.bill_id, rec_link.customer_id, 0, OLD.final_amount, NEW.final_amount);
        RETURN NEW;
    END IF;

    -- 4. UPDATE loyalty.points
    UPDATE loyalty
       SET points       = points + v_points,
           last_updated = CURRENT_DATE
     WHERE loyalty_id = rec_link.loyalty_id;

    -- 5. INSERT loyalty_transaction (default reason = first available reason)
    SELECT reason_id INTO v_default_reason FROM reason ORDER BY reason_id LIMIT 1;

    IF v_default_reason IS NOT NULL THEN
        INSERT INTO loyalty_transaction(transaction_id, points_change, created_at, loyalty_id, reason_id)
        VALUES (
            (SELECT COALESCE(MAX(transaction_id),0)+1 FROM loyalty_transaction),
            v_points, CURRENT_DATE, rec_link.loyalty_id, v_default_reason
        );
    END IF;

    -- 6. Trace into loyalty_audit_log
    INSERT INTO loyalty_audit_log(bill_id, customer_id, points_awarded, old_amount, new_amount)
    VALUES (NEW.bill_id, rec_link.customer_id, v_points, OLD.final_amount, NEW.final_amount);

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Trigger T2: ERROR % - %', SQLSTATE, SQLERRM;
        RAISE;
END;
$$;

CREATE TRIGGER trg_award_loyalty_points_on_bill_update
AFTER UPDATE ON BILL
FOR EACH ROW
EXECUTE FUNCTION fn_award_loyalty_points_on_bill_update();

COMMENT ON FUNCTION fn_award_loyalty_points_on_bill_update()
IS 'T2 - On every UPDATE of BILL.final_amount, credits loyalty points to the customer (1 per 10 €) and traces into loyalty_audit_log.';
