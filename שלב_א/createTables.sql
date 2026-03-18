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
    discount DECIMAL(10,2) DEFAULT 0 CONSTRAINT check_discount_amt CHECK (discount >= 0),
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
