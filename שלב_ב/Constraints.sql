-- Add constraints to the database
-- BILL table constraints
ALTER TABLE BILL
ADD CONSTRAINT check_tax CHECK (tax >= 0);

-- PAYMENT table constraints
ALTER TABLE PAYMENT
ADD CONSTRAINT check_payment_amount CHECK (amount > 0);

-- DISCOUNT table constraints
ALTER TABLE DISCOUNT
ADD CONSTRAINT check_percentage CHECK (percentage >= 0 AND percentage <= 100);