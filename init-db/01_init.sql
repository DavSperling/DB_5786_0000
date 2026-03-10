-- ============================================================
-- DEPARTEMENT 2 : ORDERS & BILLING
-- Base de données : PostgreSQL
-- ============================================================

-- 1. Table DISCOUNT
-- Stocke les promotions disponibles
CREATE TABLE DISCOUNT (
    discount_id INT PRIMARY KEY,
    discount_name VARCHAR(100) NOT NULL,
    percentage DECIMAL(5,2) NOT NULL CONSTRAINT check_percentage CHECK (percentage >= 0 AND percentage <= 100),
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    CONSTRAINT check_dates CHECK (valid_to >= valid_from)
);

-- 2. Table ORDER (Note: "ORDER" est un mot réservé, on utilise des guillemets)
-- Contient les informations générales de la commande
CREATE TABLE "ORDER" (
    order_id INT PRIMARY KEY,
    table_id INT NOT NULL,      -- FK externe (Dept 1)
    customer_id INT,            -- FK externe (Dept 1)
    waiter_id INT NOT NULL,     -- FK externe (Dept 6)
    order_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status VARCHAR(20) NOT NULL CONSTRAINT check_order_status 
        CHECK (order_status IN ('Pending', 'In Progress', 'Completed', 'Cancelled'))
);

-- 3. Table ORDER_ITEM
-- Détaille chaque plat commandé dans une commande
CREATE TABLE ORDER_ITEM (
    order_item_id INT PRIMARY KEY,
    order_id INT NOT NULL,      -- FK interne
    menu_item_id INT NOT NULL,  -- FK externe (Dept 3)
    quantity INT NOT NULL CONSTRAINT check_quantity CHECK (quantity > 0),
    special_request TEXT,
    CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) REFERENCES "ORDER"(order_id) ON DELETE CASCADE
);

-- 4. Table BILL
-- La facture générée pour une commande
CREATE TABLE BILL (
    bill_id INT PRIMARY KEY,
    order_id INT NOT NULL UNIQUE, -- Une facture par commande
    total_amount DECIMAL(10,2) NOT NULL CONSTRAINT check_total CHECK (total_amount >= 0),
    tax DECIMAL(10,2) NOT NULL CONSTRAINT check_tax CHECK (tax >= 0),
    discount_amount DECIMAL(10,2) DEFAULT 0 CONSTRAINT check_discount_amt CHECK (discount_amount >= 0),
    final_amount DECIMAL(10,2) NOT NULL CONSTRAINT check_final CHECK (final_amount >= 0),
    bill_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bill_order FOREIGN KEY (order_id) REFERENCES "ORDER"(order_id)
);

-- 5. Table PAYMENT
-- Enregistre le paiement de la facture
CREATE TABLE PAYMENT (
    payment_id INT PRIMARY KEY,
    bill_id INT NOT NULL,       -- FK interne
    payment_method VARCHAR(30) NOT NULL CONSTRAINT check_payment_method 
        CHECK (payment_method IN ('Cash', 'Credit Card', 'Debit Card', 'Mobile Payment')),
    payment_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(10,2) NOT NULL CONSTRAINT check_payment_amount CHECK (amount > 0),
    CONSTRAINT fk_payment_bill FOREIGN KEY (bill_id) REFERENCES BILL(bill_id)
);

-- 6. Table BILL_DISCOUNT (Table de liaison)
-- Permet d'appliquer une ou plusieurs remises à une facture
CREATE TABLE BILL_DISCOUNT (
    bill_discount_id INT PRIMARY KEY,
    bill_id INT NOT NULL,       -- FK interne
    discount_id INT NOT NULL,   -- FK interne
    CONSTRAINT fk_bd_bill FOREIGN KEY (bill_id) REFERENCES BILL(bill_id),
    CONSTRAINT fk_bd_discount FOREIGN KEY (discount_id) REFERENCES DISCOUNT(discount_id)
);


-- ============================================================
-- INSERTIONS POUR LE DEPARTEMENT 2 : ORDERS & BILLING
-- ============================================================

-- 1. Remplissage de la table DISCOUNT (Promotions)
INSERT INTO DISCOUNT (discount_id, discount_name, percentage, valid_from, valid_to) VALUES
(1, 'Happy Hour', 20.00, '2023-01-01', '2025-12-31'),
(2, 'Student Discount', 10.00, '2023-01-01', '2025-12-31'),
(3, 'Welcome Offer', 15.00, '2023-01-01', '2025-12-31');

-- 2. Remplissage de la table ORDER (Commandes)
INSERT INTO "ORDER" (order_id, table_id, customer_id, waiter_id, order_time, order_status) VALUES
(101, 5, 1, 10, '2023-10-25 12:30:00', 'Completed'),
(102, 8, 2, 11, '2023-10-25 13:00:00', 'Completed'),
(103, 3, 3, 10, '2023-10-25 19:15:00', 'In Progress');

-- 3. Remplissage de la table ORDER_ITEM (Articles dans la commande)
INSERT INTO ORDER_ITEM (order_item_id, order_id, menu_item_id, quantity, special_request) VALUES
(1, 101, 50, 2, 'Sans oignons sur une pizza'),
(2, 101, 75, 2, 'Glaçons à part'),
(3, 102, 55, 1, 'Cuit à point');

-- 4. Remplissage de la table BILL (Factures)
INSERT INTO BILL (bill_id, order_id, total_amount, tax, discount_amount, final_amount, bill_time) VALUES
(501, 101, 40.00, 4.00, 8.00, 36.00, '2023-10-25 13:45:00'),
(502, 102, 15.00, 1.50, 0.00, 16.50, '2023-10-25 14:10:00');

-- 5. Remplissage de la table PAYMENT (Paiements)
INSERT INTO PAYMENT (payment_id, bill_id, payment_method, payment_time, amount) VALUES
(901, 501, 'Credit Card', '2023-10-25 13:50:00', 36.00),
(902, 502, 'Cash', '2023-10-25 14:15:00', 16.50);

-- 6. Remplissage de la table BILL_DISCOUNT (Lien Facture <-> Promo)
INSERT INTO BILL_DISCOUNT (bill_discount_id, bill_id, discount_id) VALUES
(1, 501, 1);