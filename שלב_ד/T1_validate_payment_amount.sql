-- ============================================================
-- שלב ד - TRIGGER 1
-- Nom        : trg_validate_payment_amount
-- Quand      : BEFORE INSERT OR UPDATE on PAYMENT
-- But        : Empêche d'enregistrer un paiement dont le montant
--              dépasse strictement le final_amount de la facture
--              associée (lutte contre les erreurs de saisie).
--              Si on paie pile la facture -> OK.
--              Si NEW.amount > BILL.final_amount -> exception.
--              Met également la date de paiement à CURRENT_TIMESTAMP
--              quand elle est NULL (cohérence des données).
--
-- Éléments PL/pgSQL utilisés :
--   • Curseur implicite via SELECT INTO              ✔
--   • Record                                         ✔
--   • Branchement IF                                 ✔
--   • Exception (custom + NO_DATA_FOUND)             ✔
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
    -- Curseur implicite : SELECT ... INTO
    SELECT b.final_amount
      INTO v_bill_total
      FROM bill b
     WHERE b.bill_id = NEW.bill_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Trigger T1 : la facture % référencée par le paiement n''existe pas.',
            NEW.bill_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Branche : montant > total facture -> rejet
    IF NEW.amount > v_bill_total THEN
        RAISE EXCEPTION
            'Trigger T1 : paiement % > montant facture % (bill_id=%).',
            NEW.amount, v_bill_total, NEW.bill_id
            USING ERRCODE = '23514';     -- check_violation
    END IF;

    -- Cohérence : si payment_time est NULL, on le fixe à maintenant
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
IS 'T1 - Empêche l''enregistrement d''un paiement supérieur au final_amount de la facture associée, et complète payment_time si NULL.';
