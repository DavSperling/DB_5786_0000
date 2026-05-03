-- ============================================================
-- Stage 4 - TRIGGER 1
-- Name       : trg_validate_payment_amount
-- Fires      : BEFORE INSERT OR UPDATE on PAYMENT
-- Purpose    : Prevents recording a payment whose amount is
--              strictly greater than the final_amount of the
--              associated bill (guards against data-entry
--              errors). A payment that exactly matches the
--              bill is allowed. If NEW.amount > BILL.final_amount
--              an exception is raised. Also fills payment_time
--              with CURRENT_TIMESTAMP when it is NULL.
--
-- PL/pgSQL elements used:
--   * Implicit cursor via SELECT INTO              [x]
--   * Record                                       [x]
--   * Branching IF                                 [x]
--   * Exception (custom + NO_DATA_FOUND)           [x]
-- ============================================================

DROP TRIGGER  IF EXISTS trg_validate_payment_amount ON PAYMENT;
DROP FUNCTION IF EXISTS fn_validate_payment_amount();

CREATE OR REPLACE FUNCTION fn_validate_payment_amount()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_bill_total NUMERIC(10,2);
BEGIN
    -- Implicit cursor: SELECT ... INTO
    SELECT b.final_amount
      INTO v_bill_total
      FROM bill b
     WHERE b.bill_id = NEW.bill_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Trigger T1: bill % referenced by the payment does not exist.',
            NEW.bill_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Branch: payment amount > bill total -> reject
    IF NEW.amount > v_bill_total THEN
        RAISE EXCEPTION
            'Trigger T1: payment % > bill amount % (bill_id=%).',
            NEW.amount, v_bill_total, NEW.bill_id
            USING ERRCODE = '23514';     -- check_violation
    END IF;

    -- Consistency: if payment_time is NULL, set it to now
    IF NEW.payment_time IS NULL THEN
        NEW.payment_time := CURRENT_TIMESTAMP;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_payment_amount
BEFORE INSERT OR UPDATE ON PAYMENT
FOR EACH ROW
EXECUTE FUNCTION fn_validate_payment_amount();

COMMENT ON FUNCTION fn_validate_payment_amount()
IS 'T1 - Prevents recording a payment that exceeds the final_amount of the associated bill, and fills payment_time when NULL.';
