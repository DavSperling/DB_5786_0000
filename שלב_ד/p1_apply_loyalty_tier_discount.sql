-- ============================================================
-- Stage 4 - PROCEDURE 1
-- Name       : apply_loyalty_tier_discount
-- Type       : PROCEDURE
-- Purpose    : For every customer of a given loyalty tier,
--              applies an extra discount (in %) to ALL their
--              bills whose order is still 'In Progress'.
--              The discount is capped per tier (CASE):
--                 Bronze   -> max 10%
--                 Silver   -> max 15%
--                 Gold     -> max 20%
--                 Platinum -> max 30%
--              For every updated bill, we also INSERT a loyalty
--              transaction (= 2 DML statements, satisfies the
--              DML requirement). Updates are performed inside a
--              loop walking an EXPLICIT cursor (DECLARE/OPEN).
--
-- PL/pgSQL elements used:
--   * EXPLICIT cursor                                [x]
--   * Record (FETCH INTO)                            [x]
--   * Loop LOOP                                      [x]
--   * Branching CASE + IF                            [x]
--   * DML: UPDATE bill (2 columns)                   [x]
--   * DML: INSERT INTO loyalty_transaction           [x]
--   * Exception (raise_exception, OTHERS)            [x]
-- ============================================================

DROP PROCEDURE IF EXISTS apply_loyalty_tier_discount(VARCHAR, NUMERIC);

CREATE OR REPLACE PROCEDURE apply_loyalty_tier_discount(
    p_tier      VARCHAR,
    p_extra_pct NUMERIC          -- expressed as a percentage, e.g. 5 for 5%
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- ---- Explicit cursor: eligible bills + customer tier ----
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
    -- ---------- 1. Input validation ----------
    IF p_tier NOT IN ('Bronze','Silver','Gold','Platinum') THEN
        RAISE EXCEPTION 'Invalid tier "%".', p_tier
            USING ERRCODE = '22023';
    END IF;

    IF p_extra_pct IS NULL OR p_extra_pct < 0 OR p_extra_pct > 100 THEN
        RAISE EXCEPTION 'Invalid percentage (got: %). Expected between 0 and 100.',
                        p_extra_pct
            USING ERRCODE = '22023';
    END IF;

    -- ---------- 2. Per-tier cap (CASE) ----------
    v_max_pct := CASE p_tier
                     WHEN 'Bronze'   THEN 10
                     WHEN 'Silver'   THEN 15
                     WHEN 'Gold'     THEN 20
                     WHEN 'Platinum' THEN 30
                 END;

    v_applied_pct := LEAST(p_extra_pct, v_max_pct);

    IF v_applied_pct < p_extra_pct THEN
        RAISE NOTICE 'Requested percentage (%) capped at % for tier %.',
                     p_extra_pct, v_applied_pct, p_tier;
    END IF;

    -- ---------- 3. Pick an existing reason for the loyalty transactions ----------
    SELECT reason_id
      INTO v_default_reason
      FROM reason
     ORDER BY reason_id
     LIMIT 1;

    IF v_default_reason IS NULL THEN
        RAISE EXCEPTION 'No row in table "reason": cannot insert into loyalty_transaction.'
            USING ERRCODE = 'P0002';
    END IF;

    -- ---------- 4. Walk the explicit cursor ----------
    OPEN cur_eligible(p_tier);
    LOOP
        FETCH cur_eligible INTO rec;
        EXIT WHEN NOT FOUND;

        -- Computations
        v_extra_amount := ROUND(rec.total_amount * v_applied_pct / 100, 2);
        v_new_discount := COALESCE(rec.discount_amount, 0) + v_extra_amount;
        v_new_final    := GREATEST(rec.total_amount - v_new_discount, 0);

        -- DML #1: UPDATE bill
        UPDATE bill
           SET discount_amount = v_new_discount,
               final_amount    = v_new_final
         WHERE bill_id = rec.bill_id;

        -- DML #2: INSERT loyalty_transaction (1 loyalty point per euro of discount)
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

    RAISE NOTICE 'apply_loyalty_tier_discount: tier=%, applied_pct=%, bills_updated=%',
                 p_tier, v_applied_pct, v_count;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'apply_loyalty_tier_discount: ERROR % - %', SQLSTATE, SQLERRM;
        RAISE;
END;
$$;

COMMENT ON PROCEDURE apply_loyalty_tier_discount(VARCHAR, NUMERIC)
IS 'P1 - Applies an extra discount (capped per tier) to the in-progress bills of customers of the given tier, and credits matching loyalty points.';
