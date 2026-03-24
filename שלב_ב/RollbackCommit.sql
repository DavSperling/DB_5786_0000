
-- ============================================================
-- PART 1 : ROLLBACK
-- ============================================================

-- Initial state
SELECT bill_id, total_amount, tax, discount FROM BILL;

BEGIN;

-- Update: set discount to 10.00 for all bills
UPDATE BILL
SET discount = 10.00
RETURNING *;

-- State after update (discount = 10.00 for all)
SELECT bill_id, total_amount, tax, discount FROM BILL;

-- Cancel the update
ROLLBACK;

-- State after rollback (discount back to original)
SELECT bill_id, total_amount, tax, discount FROM BILL;


-- ============================================================
-- PART 2 : COMMIT
-- ============================================================

-- Initial state
SELECT discount_id, discount_name, percentage, valid_to FROM DISCOUNT;

BEGIN;

-- Update: extend all discounts validity by 1 month
UPDATE DISCOUNT
SET valid_to = valid_to + INTERVAL '1 month'
RETURNING *;

-- State after update (valid_to extended by 1 month)
SELECT discount_id, discount_name, percentage, valid_to FROM DISCOUNT;

-- Confirm the update permanently
COMMIT;

-- State after commit (changes are permanent)
SELECT discount_id, discount_name, percentage, valid_to FROM DISCOUNT;