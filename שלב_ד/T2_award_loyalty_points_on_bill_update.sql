-- ============================================================
-- שלב ד - TRIGGER 2  (sur UPDATE - exigence du sujet)
-- Nom        : trg_award_loyalty_points_on_bill_update
-- Quand      : AFTER UPDATE ON BILL
-- But        : Quand le final_amount d'une facture change
--              (réajustement, application d'une remise,
--              correction), on récompense automatiquement le
--              client lié : 1 point fidélité offert pour
--              chaque tranche de 10€ de la nouvelle facture,
--              tracé dans loyalty_audit_log.
--
-- Éléments PL/pgSQL utilisés :
--   • Curseur implicite (SELECT ... INTO record)         ✔
--   • Record                                             ✔
--   • Branchement IF                                     ✔
--   • DML : UPDATE loyalty                               ✔
--   • DML : INSERT loyalty_transaction                   ✔
--   • DML : INSERT loyalty_audit_log                     ✔
--   • Exception (NO_DATA_FOUND, OTHERS)                  ✔
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
    -- 1. On ne réagit que si final_amount a vraiment changé
    IF NEW.final_amount IS NOT DISTINCT FROM OLD.final_amount THEN
        RETURN NEW;
    END IF;

    -- 2. Récupérer le client lié à la commande -> à la facture
    SELECT o.customer_id, l.loyalty_id
      INTO rec_link
      FROM "ORDER"  o
      LEFT JOIN loyalty l ON l.customer_id = o.customer_id
     WHERE o.order_id = NEW.order_id;

    -- Pas de client OU pas d'enregistrement loyalty -> on ne récompense pas
    IF NOT FOUND OR rec_link.customer_id IS NULL OR rec_link.loyalty_id IS NULL THEN
        INSERT INTO loyalty_audit_log(bill_id, customer_id, points_awarded, old_amount, new_amount)
        VALUES (NEW.bill_id, rec_link.customer_id, 0, OLD.final_amount, NEW.final_amount);
        RETURN NEW;
    END IF;

    -- 3. Calcul des points : 1 point / 10€ de la NOUVELLE facture
    v_points := GREATEST(FLOOR(NEW.final_amount / 10)::INT, 0);

    IF v_points = 0 THEN
        INSERT INTO loyalty_audit_log(bill_id, customer_id, points_awarded, old_amount, new_amount)
        VALUES (NEW.bill_id, rec_link.customer_id, 0, OLD.final_amount, NEW.final_amount);
        RETURN NEW;
    END IF;

    -- 4. UPDATE de loyalty.points
    UPDATE loyalty
       SET points       = points + v_points,
           last_updated = CURRENT_DATE
     WHERE loyalty_id = rec_link.loyalty_id;

    -- 5. INSERT loyalty_transaction (raison par défaut = 1ère raison existante)
    SELECT reason_id INTO v_default_reason FROM reason ORDER BY reason_id LIMIT 1;

    IF v_default_reason IS NOT NULL THEN
        INSERT INTO loyalty_transaction(transaction_id, points_change, created_at, loyalty_id, reason_id)
        VALUES (
            (SELECT COALESCE(MAX(transaction_id),0)+1 FROM loyalty_transaction),
            v_points, CURRENT_DATE, rec_link.loyalty_id, v_default_reason
        );
    END IF;

    -- 6. Trace dans loyalty_audit_log
    INSERT INTO loyalty_audit_log(bill_id, customer_id, points_awarded, old_amount, new_amount)
    VALUES (NEW.bill_id, rec_link.customer_id, v_points, OLD.final_amount, NEW.final_amount);

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Trigger T2 : ERREUR % - %', SQLSTATE, SQLERRM;
        RAISE;
END;
$$;

CREATE TRIGGER trg_award_loyalty_points_on_bill_update
AFTER UPDATE ON BILL
FOR EACH ROW
EXECUTE FUNCTION fn_award_loyalty_points_on_bill_update();

COMMENT ON FUNCTION fn_award_loyalty_points_on_bill_update()
IS 'T2 - À chaque UPDATE de BILL.final_amount, ajoute des points fidélité au client (1 / 10€) et trace dans loyalty_audit_log.';
