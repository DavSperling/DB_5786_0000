-- ============================================================
-- שלב ג - INTEGRATION (Méthode א - intégration totale)
-- Département cible (local)  : ORDERS & BILLING (restaurant_db)
-- Département importé (remote): CUSTOMER / RESERVATIONS / LOYALTY (other_group_db)
-- Technique : postgres_fdw utilisé comme pont de transfert,
--             puis foreign tables supprimées en fin de script.
-- ============================================================

-- =====================================================================
-- PHASE 0 : NETTOYAGE (idempotent)
--    Permet de relancer le script sans erreur si déjà exécuté.
-- =====================================================================
ALTER TABLE "ORDER" DROP CONSTRAINT IF EXISTS fk_order_customer;
DROP TABLE IF EXISTS feedback CASCADE;
DROP TABLE IF EXISTS waitlist CASCADE;
DROP TABLE IF EXISTS loyalty_transaction CASCADE;
DROP TABLE IF EXISTS loyalty CASCADE;
DROP TABLE IF EXISTS reservation CASCADE;
DROP TABLE IF EXISTS reason CASCADE;
DROP TABLE IF EXISTS loyalty_tier CASCADE;
DROP TABLE IF EXISTS status_type CASCADE;
DROP TABLE IF EXISTS customer CASCADE;
DROP SERVER IF EXISTS other_group_server CASCADE;

-- =====================================================================
-- PHASE 1 : SETUP DU FOREIGN DATA WRAPPER
-- =====================================================================

-- 1.1 Activer l'extension postgres_fdw qui permet à PostgreSQL de
--     dialoguer avec d'autres bases PostgreSQL via des "tables étrangères".
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- 1.2 Définir le serveur distant : la base other_group_db
--     (sur le même conteneur PostgreSQL, port interne 5432).
CREATE SERVER other_group_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'localhost', dbname 'other_group_db', port '5432');

-- 1.3 Authentification : associer l'utilisateur local 'admin' aux
--     credentials de la base distante.
CREATE USER MAPPING FOR admin
SERVER other_group_server
OPTIONS (user 'admin', password 'admin123');


-- =====================================================================
-- PHASE 2 : IMPORT DES 9 TABLES
--    Ordre respecté pour les FK : référentiels → customer → tables liées.
-- =====================================================================

-- ---------- 2.1  loyalty_tier  (référentiel - aucune FK) ----------
CREATE FOREIGN TABLE loyalty_tier_remote (
    tier_id INTEGER,
    level   VARCHAR(50)
) SERVER other_group_server
OPTIONS (schema_name 'public', table_name 'loyalty_tier');

CREATE TABLE loyalty_tier (
    tier_id INT PRIMARY KEY,
    level   VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO loyalty_tier (tier_id, level)
SELECT tier_id, level FROM loyalty_tier_remote;


-- ---------- 2.2  reason  (référentiel - aucune FK) ----------
CREATE FOREIGN TABLE reason_remote (
    reason_id   INTEGER,
    description VARCHAR(100)
) SERVER other_group_server
OPTIONS (schema_name 'public', table_name 'reason');

CREATE TABLE reason (
    reason_id   INT PRIMARY KEY,
    description VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO reason (reason_id, description)
SELECT reason_id, description FROM reason_remote;


-- ---------- 2.3  status_type  (référentiel - aucune FK) ----------
CREATE FOREIGN TABLE status_type_remote (
    status_id   INTEGER,
    description VARCHAR(50)
) SERVER other_group_server
OPTIONS (schema_name 'public', table_name 'status_type');

CREATE TABLE status_type (
    status_id   INT PRIMARY KEY,
    description VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO status_type (status_id, description)
SELECT status_id, description FROM status_type_remote;


-- ---------- 2.4  customer  (table pivot - aucune FK sortante) ----------
CREATE FOREIGN TABLE customer_remote (
    customer_id INTEGER,
    first_name  VARCHAR(50),
    last_name   VARCHAR(50),
    phone       VARCHAR(15),
    email       VARCHAR(100),
    created_at  DATE,
    is_active   INTEGER
) SERVER other_group_server
OPTIONS (schema_name 'public', table_name 'customer');

CREATE TABLE customer (
    customer_id INT PRIMARY KEY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    phone       VARCHAR(15)  NOT NULL UNIQUE,
    email       VARCHAR(100) NOT NULL UNIQUE,
    created_at  DATE         NOT NULL,
    is_active   INTEGER      DEFAULT 1,
    CONSTRAINT chk_names_different
        CHECK (lower(first_name) <> lower(last_name)),
    CONSTRAINT customer_email_check
        CHECK (email LIKE '%_@_%.__%'),
    CONSTRAINT customer_is_active_check
        CHECK (is_active IN (0, 1)),
    CONSTRAINT customer_phone_check
        CHECK (length(phone) >= 7)
);

INSERT INTO customer (customer_id, first_name, last_name, phone, email, created_at, is_active)
SELECT customer_id, first_name, last_name, phone, email, created_at, is_active
FROM customer_remote;


-- ---------- 2.5  loyalty  (FK → customer, loyalty_tier) ----------
CREATE FOREIGN TABLE loyalty_remote (
    loyalty_id   INTEGER,
    points       INTEGER,
    last_updated DATE,
    customer_id  INTEGER,
    tier_id      INTEGER
) SERVER other_group_server
OPTIONS (schema_name 'public', table_name 'loyalty');

CREATE TABLE loyalty (
    loyalty_id   INT PRIMARY KEY,
    points       INT  NOT NULL CHECK (points >= 0),
    last_updated DATE NOT NULL,
    customer_id  INT  NOT NULL UNIQUE,
    tier_id      INT  NOT NULL,
    CONSTRAINT loyalty_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT loyalty_tier_id_fkey     FOREIGN KEY (tier_id)     REFERENCES loyalty_tier(tier_id)
);

INSERT INTO loyalty (loyalty_id, points, last_updated, customer_id, tier_id)
SELECT loyalty_id, points, last_updated, customer_id, tier_id
FROM loyalty_remote;


-- ---------- 2.6  loyalty_transaction  (FK → loyalty, reason) ----------
CREATE FOREIGN TABLE loyalty_transaction_remote (
    transaction_id INTEGER,
    points_change  INTEGER,
    created_at     DATE,
    loyalty_id     INTEGER,
    reason_id      INTEGER
) SERVER other_group_server
OPTIONS (schema_name 'public', table_name 'loyalty_transaction');

CREATE TABLE loyalty_transaction (
    transaction_id INT PRIMARY KEY,
    points_change  INT  NOT NULL CHECK (points_change <> 0),
    created_at     DATE NOT NULL,
    loyalty_id     INT  NOT NULL,
    reason_id      INT  NOT NULL,
    CONSTRAINT loyalty_transaction_loyalty_id_fkey FOREIGN KEY (loyalty_id) REFERENCES loyalty(loyalty_id),
    CONSTRAINT loyalty_transaction_reason_id_fkey  FOREIGN KEY (reason_id)  REFERENCES reason(reason_id)
);

INSERT INTO loyalty_transaction (transaction_id, points_change, created_at, loyalty_id, reason_id)
SELECT transaction_id, points_change, created_at, loyalty_id, reason_id
FROM loyalty_transaction_remote;


-- ---------- 2.7  reservation  (FK → customer, status_type) ----------
CREATE FOREIGN TABLE reservation_remote (
    reservation_id   INTEGER,
    datetime         DATE,
    party_size       INTEGER,
    special_requests VARCHAR(255),
    created_at       DATE,
    customer_id      INTEGER,
    status_id        INTEGER
) SERVER other_group_server
OPTIONS (schema_name 'public', table_name 'reservation');

CREATE TABLE reservation (
    reservation_id   INT PRIMARY KEY,
    datetime         DATE NOT NULL,
    party_size       INT  NOT NULL CHECK (party_size > 0 AND party_size <= 20),
    special_requests VARCHAR(255),
    created_at       DATE NOT NULL,
    customer_id      INT  NOT NULL,
    status_id        INT  NOT NULL,
    CONSTRAINT chk_reservation_future_date CHECK (datetime >= created_at),
    CONSTRAINT reservation_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT reservation_status_id_fkey   FOREIGN KEY (status_id)   REFERENCES status_type(status_id)
);

INSERT INTO reservation (reservation_id, datetime, party_size, special_requests, created_at, customer_id, status_id)
SELECT reservation_id, datetime, party_size, special_requests, created_at, customer_id, status_id
FROM reservation_remote;


-- ---------- 2.8  feedback  (FK → reservation) ----------
CREATE FOREIGN TABLE feedback_remote (
    feedback_id    INTEGER,
    rating         INTEGER,
    comment        VARCHAR(500),
    feedback_date  DATE,
    reservation_id INTEGER
) SERVER other_group_server
OPTIONS (schema_name 'public', table_name 'feedback');

CREATE TABLE feedback (
    feedback_id    INT PRIMARY KEY,
    rating         INT  NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment        VARCHAR(500),
    feedback_date  DATE NOT NULL,
    reservation_id INT  NOT NULL UNIQUE,
    CONSTRAINT chk_meaningful_comment
        CHECK (comment IS NULL OR length(trim(comment)) >= 4),
    CONSTRAINT feedback_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES reservation(reservation_id)
);

INSERT INTO feedback (feedback_id, rating, comment, feedback_date, reservation_id)
SELECT feedback_id, rating, comment, feedback_date, reservation_id
FROM feedback_remote;


-- ---------- 2.9  waitlist  (FK → customer, status_type) ----------
CREATE FOREIGN TABLE waitlist_remote (
    waitlist_id   INTEGER,
    party_size    INTEGER,
    request_time  DATE,
    est_wait_time INTEGER,
    customer_id   INTEGER,
    status_id     INTEGER
) SERVER other_group_server
OPTIONS (schema_name 'public', table_name 'waitlist');

CREATE TABLE waitlist (
    waitlist_id   INT PRIMARY KEY,
    party_size    INT  NOT NULL CHECK (party_size > 0 AND party_size <= 20),
    request_time  DATE NOT NULL,
    est_wait_time INT  NOT NULL CHECK (est_wait_time >= 0 AND est_wait_time <= 300),
    customer_id   INT  NOT NULL,
    status_id     INT  NOT NULL,
    CONSTRAINT waitlist_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    CONSTRAINT waitlist_status_id_fkey   FOREIGN KEY (status_id)   REFERENCES status_type(status_id)
);

INSERT INTO waitlist (waitlist_id, party_size, request_time, est_wait_time, customer_id, status_id)
SELECT waitlist_id, party_size, request_time, est_wait_time, customer_id, status_id
FROM waitlist_remote;


-- =====================================================================
-- PHASE 3 : LIEN D'INTÉGRATION
--    On exploite le pivot naturel entre les 2 départements :
--    "ORDER".customer_id (déjà présent côté local) → customer(customer_id) (côté importé).
--
--    PROBLÈME : nos données Mockaroo ont généré des customer_id
--    aléatoires (1..999974) qui ne correspondent pas aux 500 clients réels.
--    DÉCISION : on remappe chaque customer_id sur la plage [1..500]
--    via la formule ((customer_id - 1) % 500) + 1, ce qui distribue
--    uniformément les commandes sur les 500 clients existants.
-- =====================================================================

-- 3.1 Re-mapping des customer_id de la table ORDER
UPDATE "ORDER"
SET    customer_id = ((customer_id - 1) % 500) + 1
WHERE  customer_id IS NOT NULL;

-- 3.2 Vérification : tous les customer_id de ORDER doivent maintenant exister dans customer
--     (Cette requête ne doit retourner aucune ligne)
SELECT o.order_id, o.customer_id
FROM   "ORDER" o
LEFT JOIN customer c ON o.customer_id = c.customer_id
WHERE  o.customer_id IS NOT NULL AND c.customer_id IS NULL;

-- 3.3 Création de la clé étrangère ORDER → customer
ALTER TABLE "ORDER"
ADD CONSTRAINT fk_order_customer
FOREIGN KEY (customer_id) REFERENCES customer(customer_id);


-- =====================================================================
-- PHASE 4 : NETTOYAGE
--    Une fois les données copiées dans les vraies tables locales,
--    les foreign tables ne servent plus → on les supprime.
-- =====================================================================
DROP FOREIGN TABLE customer_remote;
DROP FOREIGN TABLE loyalty_tier_remote;
DROP FOREIGN TABLE reason_remote;
DROP FOREIGN TABLE status_type_remote;
DROP FOREIGN TABLE loyalty_remote;
DROP FOREIGN TABLE loyalty_transaction_remote;
DROP FOREIGN TABLE reservation_remote;
DROP FOREIGN TABLE feedback_remote;
DROP FOREIGN TABLE waitlist_remote;


-- =====================================================================
-- PHASE 5 : CONTRÔLES POST-INTÉGRATION
-- =====================================================================
SELECT 'customer'            AS table_name, COUNT(*) FROM customer
UNION ALL SELECT 'loyalty_tier',            COUNT(*) FROM loyalty_tier
UNION ALL SELECT 'reason',                  COUNT(*) FROM reason
UNION ALL SELECT 'status_type',             COUNT(*) FROM status_type
UNION ALL SELECT 'loyalty',                 COUNT(*) FROM loyalty
UNION ALL SELECT 'loyalty_transaction',     COUNT(*) FROM loyalty_transaction
UNION ALL SELECT 'reservation',             COUNT(*) FROM reservation
UNION ALL SELECT 'feedback',                COUNT(*) FROM feedback
UNION ALL SELECT 'waitlist',                COUNT(*) FROM waitlist
UNION ALL SELECT '"ORDER"',                 COUNT(*) FROM "ORDER"
UNION ALL SELECT 'order_item',              COUNT(*) FROM order_item
UNION ALL SELECT 'bill',                    COUNT(*) FROM bill
UNION ALL SELECT 'payment',                 COUNT(*) FROM payment
UNION ALL SELECT 'discount',                COUNT(*) FROM discount
UNION ALL SELECT 'bill_discount',           COUNT(*) FROM bill_discount
ORDER BY table_name;
