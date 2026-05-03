-- ============================================================
-- INSERTS FOR DEPARTMENT 2: ORDERS & BILLING
-- Database: PostgreSQL
-- 3 different insertion methods
-- ============================================================

-- ==========================================================
-- METHOD 1: Inserting with all columns specified explicitly
-- ==========================================================
INSERT INTO DISCOUNT (discount_id, discount_name, percentage, valid_from, valid_to)
VALUES (1, 'Happy Hour', 20.00, '2023-01-01', '2025-12-31');

INSERT INTO "ORDER" (order_id, table_id, customer_id, waiter_id, order_time, order_status)
VALUES (101, 5, 1, 10, '2023-10-25 12:30:00', 'Completed');

INSERT INTO ORDER_ITEM (order_item_id, order_id, menu_item_id, quantity, special_request)
VALUES (1, 101, 50, 2, 'No onions on the pizza');

-- ==========================================================
-- METHOD 2: Inserting implicitly (no column names, values must match schema order)
-- ==========================================================
INSERT INTO DISCOUNT
VALUES (2, 'Student Discount', 10.00, '2023-01-01', '2025-12-31');

INSERT INTO "ORDER"
VALUES (102, 8, 2, 11, '2023-10-25 13:00:00', 'Completed');

INSERT INTO ORDER_ITEM
VALUES (2, 101, 75, 2, 'Ice on the side');

-- ==========================================================
-- METHOD 3: Multi-row INSERT (PostgreSQL syntax)
-- ==========================================================
INSERT INTO DISCOUNT (discount_id, discount_name, percentage, valid_from, valid_to) VALUES
(3, 'Welcome Offer', 15.00, '2023-01-01', '2025-12-31'),
(4, 'Weekend Special', 25.00, '2023-06-01', '2025-12-31');

INSERT INTO "ORDER" (order_id, table_id, customer_id, waiter_id, order_time, order_status) VALUES
(103, 3, 3, 10, '2023-10-25 19:15:00', 'In Progress'),
(104, 6, 4, 12, '2023-10-26 20:00:00', 'Pending');

INSERT INTO ORDER_ITEM (order_item_id, order_id, menu_item_id, quantity, special_request) VALUES
(3, 102, 55, 1, 'Cooked medium'),
(4, 103, 60, 3, NULL);

-- ==========================================================
-- General insertions for other tables
-- ==========================================================
INSERT INTO BILL (bill_id, order_id, total_amount, tax, discount, bill_time)
VALUES (501, 101, 40.00, 4.00, 8.00, '2023-10-25 13:45:00');

INSERT INTO BILL
VALUES (502, 102, 15.00, 1.50, 0.00, '2023-10-25 14:10:00');

INSERT INTO PAYMENT (payment_id, bill_id, payment_method, payment_time, amount)
VALUES (901, 501, 'Credit Card', '2023-10-25 13:50:00', 36.00);

INSERT INTO PAYMENT
VALUES (902, 502, 'Cash', '2023-10-25 14:15:00', 16.50);

INSERT INTO BILL_DISCOUNT (bill_discount_id, bill_id, discount_id)
VALUES (1, 501, 1);
