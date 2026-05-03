# DB_5786_0000 — Restaurant Order & Billing Database

📘 Project Report
This project is a restaurant order and billing database management system. It was developed as part of a database course project.

---

## 🧑‍💻 Authors

* Dylan Athouel
* David Sperling

---

## 🏢 Project Scope

* **System:** Restaurant Management System
* **Unit:** Order & Billing Department

---

## 📌 Table of Contents

### 🔵 Stage 1
1. [Overview](#-overview)
2. [Application Mockup (UI)](#-application-mockup-ui)
3. [ERD and DSD Diagrams](#-erd-and-dsd-diagrams)
4. [Data Structure Description](#-data-structure-description)
5. [Data Insertion Methods](#-data-insertion-methods)
6. [Backup & Restore](#-backup--restore)
7. [Docker Setup](#-docker-setup-postgresql)
8. [Getting Started](#-getting-started-python-app)

### 🟠 Stage 2
9. [SELECT Queries — Dual Form (JOIN vs Subquery)](#-select-queries--dual-form-join-vs-subquery)
10. [SELECT Queries — Additional](#-select-queries--additional)
11. [UPDATE Queries](#-update-queries)
12. [DELETE Queries](#-delete-queries)
13. [Constraints (CHECK)](#-constraints-check)
14. [Backup & Restore — Stage 2](#-stage-2--backup--restore-verification)
15. [Transactions — ROLLBACK & COMMIT](#-transactions--rollback--commit)

### 🔗 Stage 3
16. [Stage 3 – Integration and Views](#-stage-3--integration-and-views)
    - [ERD and DSD Diagrams (Stage 3)](#-erd-and-dsd-diagrams-1)
    - [Reverse-Engineering Algorithm](#-reverse-engineering-algorithm-dsd--erd)
    - [Integration Decisions](#-integration-decisions)
    - [Integration Process and SQL Commands](#-integration-process-and-sql-commands)
    - [Views and Analytical Queries](#-views-and-analytical-queries)
    - [Stage 3 Conclusion](#-stage-3--conclusion)

---

## 🧾 Overview

This database system is designed to manage the operational and financial activities of a restaurant. It includes data about orders, order items, bills, payments, discounts, and billing history.

The system uses foreign keys, weak entities, and entity relationships to maintain data consistency and avoid redundancy.

---

## 💻 Application Mockup (UI)

The screenshots below represent a **UI mockup** of what the application layer could look like, designed to illustrate the real-world use case of the database.

### Login
![Login Screen](docs/login.jpeg)

### Dashboard
![Dashboard](docs/dashboard.jpeg)

### Orders & Billing
![Orders and Billing](docs/order_and_bill.jpeg)

### Menu Management
![Menu Management](docs/menu_management.jpeg)

### Staff & Tables
![Staff and Table Map](docs/staff_table.jpeg)

---

## 📁 ERD and DSD Diagrams

### ERD
![ER Diagram](docs/ERD.png)

### DSD
![Relational Schema](docs/DSD.png)

---

## 📋 Data Structure Description

Below is a summary of the main entities and their fields:

### ORDER
Stores customer orders.
* `order_id` (Primary Key)
* `table_id`
* `customer_id`
* `waiter_id`
* `order_time`
* `order_status`

### BILL
The bill generated per order.
* `bill_id` (Primary Key)
* `order_id` (Foreign Key)
* `total_amount`
* `tax`
* `discount_amount`
* `bill_time`


### PAYMENT
Payment record linked to a bill.
* `payment_id` (Primary Key)
* `bill_id` (Foreign Key)
* `payment_method`
* `payment_time`
* `amount`


### DISCOUNT
Available discounts.
* `discount_id` (Primary Key)
* `discount_name`
* `percentage`
* `valid_from`
* `valid_to`


### BILL_DISCOUNT
Junction table linking bills to applied discounts.
* `bill_discount_id` (Primary Key)
* `bill_id` (Foreign Key)
* `discount_id` (Foreign Key)

---

## 📥 Data Insertion Methods

### ✅ Method A: Python Script

Data for the `BILL_DISCOUNT` junction table was generated using a custom Python script that produces 20,000 INSERT statements into a `.sql` file.

![Python Script](docs/python_script.jpeg)

### ✅ Method B: Mockaroo Generator

Tables such as `ORDER`,`PAYMENT`, and `DISCOUNT` were populated using [Mockaroo](https://mockaroo.com/), a tool that generates realistic mock data in SQL format.

![Order Mockaroo](docs/Order.jpg)


### ✅ Method C: Mockaroo Generator CSV

Tables `BILL` was populated using [Mockaroo](https://mockaroo.com/), a tool that generates realistic mock data in CSV format.

![Bill Mockaroo](docs/Bill.jpg)

---

## 💾 Backup & Restore

### Backup

A full backup of the `restaurant_db` database was performed using pgAdmin.

![Backup](docs/backup.jpeg)

### Restore

The backup was successfully restored into a test database to verify data integrity.

![Restore](docs/restore.jpeg)

---

# 🟠 Stage 2 — Queries, Constraints & Transactions

---

## 🔍 SELECT Queries — Dual Form (JOIN vs Subquery)

For each of the following 4 queries, two equivalent versions are provided:
- **Version A** using an explicit `JOIN`
- **Version B** using a `Subquery`

Both return the same result, but differ in readability and execution efficiency.

---

### Query 1 — Orders with Bill & Payment Details

> Retrieves each order along with its total bill amount, tax, and payment method, ordered by total amount descending.

**🎯 Business Context:** A restaurant manager wants to review all orders with their financial details and payment method in a single view — useful for end-of-day reconciliation and detecting unpaid or high-value orders.


**Version A — Using JOIN**
```sql
SELECT o.order_id, o.order_status, o.order_time,
       b.total_amount, b.tax, p.payment_method
FROM "ORDER" o
JOIN BILL b ON o.order_id = b.order_id
JOIN PAYMENT p ON b.bill_id = p.bill_id
ORDER BY b.total_amount DESC;
```

![Select 1A - JOIN](docs/select_1a.jpg)

---

**Version B — Using Correlated Subqueries**
```sql
SELECT o.order_id, o.order_status, o.order_time,
       (SELECT b.total_amount FROM BILL b WHERE b.order_id = o.order_id) AS total_amount,
       (SELECT b.tax FROM BILL b WHERE b.order_id = o.order_id) AS tax,
       (SELECT p.payment_method FROM PAYMENT p
        JOIN BILL b ON p.bill_id = b.bill_id
        WHERE b.order_id = o.order_id LIMIT 1) AS payment_method
FROM "ORDER" o
ORDER BY total_amount DESC;
```

![Select 1B - Subquery](docs/select_1b.jpg)

---

> **📊 Efficiency Comparison:**
> Version A (JOIN) is significantly more efficient. The query planner executes a **single pass** over the joined tables and can leverage indexes on foreign keys. Version B (Correlated Subquery) executes **one subquery per row** of the outer `ORDER` table, resulting in O(n) additional queries — this becomes very costly as data grows. For 500 orders, Version B may execute over 1,500 subqueries internally. **JOIN is the preferred approach in production.**

---

### Query 2 — Bills with Applied Discounts & Savings

> Retrieves each bill along with the applied discount name, percentage, and the actual amount saved, ordered by savings descending.

**🎯 Business Context:** The accounting team needs to track how much revenue is lost to discounts and which promotions are most costly — essential for evaluating the profitability of discount campaigns.

**Version A — Using JOIN**
```sql
SELECT b.bill_id, b.total_amount,
       d.discount_name, d.percentage,
       ROUND(b.total_amount * d.percentage / 100, 2) AS amount_saved
FROM BILL b
JOIN BILL_DISCOUNT bd ON b.bill_id = bd.bill_id
JOIN DISCOUNT d ON bd.discount_id = d.discount_id
ORDER BY amount_saved DESC;
```

![Select 2A - JOIN](docs/select_2a.jpg)

---

**Version B — Using Subquery**
```sql
SELECT b.bill_id, b.total_amount,
       d.discount_name, d.percentage,
       ROUND(b.total_amount * d.percentage / 100, 2) AS amount_saved
FROM BILL b, BILL_DISCOUNT bd, DISCOUNT d
WHERE EXISTS (
    SELECT 1 FROM BILL_DISCOUNT bd2
    WHERE bd2.bill_id = b.bill_id AND bd2.discount_id = d.discount_id
)
AND bd.bill_id = b.bill_id AND bd.discount_id = d.discount_id
ORDER BY amount_saved DESC;
```

![Select 2B - Subquery](docs/select2_b.jpg)

---

> **📊 Efficiency Comparison:**
> Version A (JOIN) is more efficient here as well, because the three-table join is handled in a single execution plan. PostgreSQL's optimizer can use the junction table `BILL_DISCOUNT` efficiently with indexed foreign keys. Version B using subqueries would require nested lookups for each bill, increasing execution time significantly on large datasets. **JOIN is preferred for multi-table relationships.**

---

### Query 3 — Waiter Performance by Month

> Retrieves each waiter's total number of orders and total revenue generated, grouped by month and year.

**🎯 Business Context:** The restaurant owner wants to evaluate each waiter's productivity and revenue contribution per month — useful for performance reviews, bonuses, and scheduling decisions.

**Version A — Using JOIN**
```sql
SELECT o.waiter_id,
       EXTRACT(YEAR FROM o.order_time) AS year,
       EXTRACT(MONTH FROM o.order_time) AS month,
       COUNT(o.order_id) AS total_orders,
       SUM(b.total_amount) AS total_revenue
FROM "ORDER" o
JOIN BILL b ON o.order_id = b.order_id
GROUP BY o.waiter_id, EXTRACT(YEAR FROM o.order_time), EXTRACT(MONTH FROM o.order_time)
ORDER BY year, month, total_orders DESC;
```

![Select 3A - JOIN](docs/select_3a.jpg)

---

**Version B — Using Subquery (Derived Table)**
```sql
SELECT waiter_id, year, month,
       COUNT(*) AS total_orders,
       SUM(total_amount) AS total_revenue
FROM (
    SELECT o.waiter_id, o.order_id,
           EXTRACT(YEAR FROM o.order_time) AS year,
           EXTRACT(MONTH FROM o.order_time) AS month,
           b.total_amount
    FROM "ORDER" o
    JOIN BILL b ON o.order_id = b.order_id
) AS sub
GROUP BY waiter_id, year, month
ORDER BY year, month, total_orders DESC;
```

![Select 3B - Subquery](docs/select_3b.jpg)

---

> **📊 Efficiency Comparison:**
> Both versions produce identical results and have similar execution plans — the subquery in Version B is a **derived table** (non-correlated), which PostgreSQL inlines and optimizes similarly to a JOIN. However, Version A is slightly more readable and avoids the extra subquery layer. For analytical queries like this one, the difference is minimal, but **Version A (direct JOIN) is cleaner and equally efficient.**

---

### Query 4 — Payment Method Statistics by Month

> Retrieves payment method usage count and total amount paid, grouped by method, year, and month.

**🎯 Business Context:** The finance team wants to understand customer payment preferences over time — useful for deciding whether to invest in new payment terminals or negotiate lower card processing fees.

**Version A — Using JOIN**
```sql
SELECT p.payment_method,
       EXTRACT(YEAR FROM p.payment_time) AS year,
       EXTRACT(MONTH FROM p.payment_time) AS month,
       COUNT(p.payment_id) AS usage_count,
       SUM(p.amount) AS total_paid
FROM PAYMENT p
JOIN BILL b ON p.bill_id = b.bill_id
GROUP BY p.payment_method, EXTRACT(YEAR FROM p.payment_time), EXTRACT(MONTH FROM p.payment_time)
ORDER BY year, month, usage_count DESC;
```

![Select 4A - JOIN](docs/select_4a.jpg)

---

**Version B — Using Subquery (WHERE IN)**
```sql
SELECT payment_method, year, month,
       COUNT(*) AS usage_count,
       SUM(amount) AS total_paid
FROM (
    SELECT p.payment_method, p.amount,
           EXTRACT(YEAR FROM p.payment_time) AS year,
           EXTRACT(MONTH FROM p.payment_time) AS month
    FROM PAYMENT p
    WHERE p.bill_id IN (SELECT bill_id FROM BILL)
) AS sub
GROUP BY payment_method, year, month
ORDER BY year, month, usage_count DESC;
```

![Select 4B - Subquery](docs/select_4b.jpg)

---

> **📊 Efficiency Comparison:**
> Version A (JOIN) is more efficient. The `WHERE bill_id IN (SELECT ...)` in Version B forces PostgreSQL to first evaluate the full subquery and build a hash set of all `bill_id` values before filtering. While PostgreSQL often optimizes this into a semi-join internally, it adds overhead compared to a direct JOIN, especially on large tables. **Version A is preferred for both clarity and performance.**

---

## 🔍 SELECT Queries — Additional

The following 4 queries each demonstrate a specific analytical use case for the restaurant database.

---

### Query 5 — Orders Containing Special Requests

> Retrieves all order items that include a special request (e.g., "No salt", "Gluten free"), joined with their parent order details, sorted by most recent order.

**🎯 Business Context:** The kitchen manager needs to monitor special dietary requests (allergies, preferences) to ensure staff are prepared and no requests are missed during service.

```sql
SELECT o.order_id, o.order_time, o.order_status,
       oi.menu_item_id, oi.quantity, oi.special_request
FROM "ORDER" o
JOIN ORDER_ITEM oi ON o.order_id = oi.order_id
WHERE oi.special_request IS NOT NULL
ORDER BY o.order_time DESC;
```

![Select 5 - Special Requests](docs/select_5.jpg)

---

### Query 6 — Daily Revenue Report

> Aggregates the number of bills, total revenue, and total tax collected per day, sorted from most recent to oldest.

**🎯 Business Context:** Management needs a daily summary of revenue and tax collected to track business performance over time and compare busy vs slow days.

```sql
SELECT EXTRACT(DAY FROM b.bill_time) AS day,
       EXTRACT(MONTH FROM b.bill_time) AS month,
       EXTRACT(YEAR FROM b.bill_time) AS year,
       COUNT(b.bill_id) AS nb_bills,
       SUM(b.total_amount) AS daily_revenue,
       SUM(b.tax) AS daily_tax
FROM BILL b
GROUP BY EXTRACT(YEAR FROM b.bill_time),
         EXTRACT(MONTH FROM b.bill_time),
         EXTRACT(DAY FROM b.bill_time)
ORDER BY year DESC, month DESC, day DESC;
```

![Select 6 - Daily Revenue](docs/select_6.jpg)

---

### Query 7 — Cancelled Orders with Their Items

> Retrieves all order items belonging to cancelled orders, including the waiter, menu item, quantity, and date, sorted by most recent.

**🎯 Business Context:** Operations needs to investigate cancelled orders to identify patterns — for example, a specific waiter or time slot with high cancellation rates that may indicate a service problem.

```sql
SELECT o.order_id, o.order_time, o.waiter_id,
       oi.menu_item_id, oi.quantity,
       EXTRACT(YEAR FROM o.order_time) AS annee,
       EXTRACT(MONTH FROM o.order_time) AS mois
FROM "ORDER" o
JOIN ORDER_ITEM oi ON o.order_id = oi.order_id
WHERE o.order_status = 'Cancelled'
ORDER BY o.order_time DESC;
```

![Select 7 - Cancelled Orders](docs/select_7.jpg)

---

### Query 8 — Discounts Ranked by Percentage with Duration

> Lists all discounts sorted by percentage descending, with a computed column showing the number of days each discount is valid.

**🎯 Business Context:** The marketing team wants to review all active and past discounts ranked by their value — useful for auditing promotions and identifying overly generous discounts that hurt margins.

```sql
SELECT d.discount_id, d.discount_name, d.percentage,
       d.valid_from, d.valid_to,
       (d.valid_to - d.valid_from) AS duree_jours
FROM DISCOUNT d
ORDER BY d.percentage DESC;
```

![Select 8 - Discounts by Percentage](docs/select_8.jpg)

---

## ✏️ UPDATE Queries

For each UPDATE query, the state of the database **before** and **after** the operation is shown.

---

### UPDATE 1 — Set Stale "In Progress" Orders to "Cancelled"

> All orders with status `In Progress` placed more than 2 years ago are automatically set to `Cancelled`.
```sql
UPDATE "ORDER"
SET order_status = 'Cancelled'
WHERE order_status = 'In Progress'
  AND order_time < NOW() - INTERVAL '2 years'
RETURNING *;
```

**Before:**

![Order Table Before Update 1](docs/order_before.jpg)

**After:**

![Update 1 - Result](docs/update_1.jpg)

---

### UPDATE 2 — Shift All Order Times by +1 Day

> All order timestamps are incremented by one day. This query demonstrates a bulk date update with `RETURNING *` to immediately visualize the changes.
```sql
UPDATE "ORDER"
SET order_time = order_time + INTERVAL '1 day'
RETURNING *;
```

**Before:**

![Order Table Before Update 2](docs/order_before.jpg)

**After (RETURNING \*):**

![Update 2 - Result](docs/update_2.jpg)

---

### UPDATE 3 — Extend All Discount Validity by 1 Month

> All discount expiration dates (`valid_to`) are extended by one month. Useful to bulk-renew active promotions.
```sql
UPDATE DISCOUNT
SET valid_to = valid_to + INTERVAL '1 month'
RETURNING *;
```

**Before:**

![Discount Table Before Update 3](docs/discount_before.jpg)

**After (RETURNING \*):**

![Update 3 - Result](docs/update_3.jpg)

---

## 🗑️ DELETE Queries

For each DELETE query, the state of the relevant table **before** and **after** the operation is shown.

---

### DELETE 1 — Remove Payments Under 5€ (Data Entry Errors)

> Payments with an amount less than 5€ are considered data entry errors and are removed from the `PAYMENT` table.
```sql
DELETE FROM PAYMENT
WHERE amount < 5;
```

**Before:**

![Payment Table Before Delete](docs/payement_before.jpg)

**After:**

![Delete 1 - After (PAYMENT table cleaned)](docs/delete_1.jpg)

---

### DELETE 2 — Remove Discounts Expired More Than 1 Year Ago

> Discounts whose `valid_to` date is more than one year in the past are cleaned up from the `DISCOUNT` table.
```sql
DELETE FROM DISCOUNT
WHERE valid_to < CURRENT_DATE - INTERVAL '1 year';
```

**Before:**

![Discount Table Before Delete](docs/discount_before.jpg)

**After:**

![Delete 2 - After (expired discounts removed)](docs/delete_2.jpg)

---

### DELETE 3 — Remove Cancelled Orders With No Associated Bill

> Cancelled orders that never generated a bill are orphaned records. This query removes them to keep the database clean.
```sql
DELETE FROM "ORDER"
WHERE order_status = 'Cancelled'
  AND order_id NOT IN (SELECT order_id FROM BILL);
```

**Before:**

![Order Table Before Delete](docs/order_before.jpg)

**After:**

![Delete 3 - After (orphaned cancelled orders removed)](docs/delete_3.jpg)

---

## 🔒 Constraints (CHECK)

The following `CHECK` constraints were added to the database using `ALTER TABLE` to enforce data integrity rules. Each section demonstrates the constraint violation with an intentional bad `INSERT`.

---

### Constraint 1 — Tax Must Be Non-Negative (`BILL` table)

> **ALTER TABLE change:** A `CHECK` constraint named `check_tax` was added to the `BILL` table to ensure that the `tax` column cannot contain negative values.
```sql
ALTER TABLE BILL ADD CONSTRAINT check_tax CHECK (tax >= 0);
```

**Violation test — inserting a negative tax:**
```sql
INSERT INTO BILL (bill_id, order_id, total_amount, tax, discount_amount, final_amount, bill_time)
VALUES (999, 1, 50.00, -5.00, 0, 45.00, CURRENT_TIMESTAMP);
```

![Constraint 1 - Check Tax Error](docs/constraint_1.jpg)

> ❌ The database correctly rejects the insertion with: `ERROR: new row for relation "bill" violates check constraint "check_tax"`

---

### Constraint 2 — Payment Amount Must Be Positive (`PAYMENT` table)

> **ALTER TABLE change:** A `CHECK` constraint named `check_payment_amount` was added to the `PAYMENT` table to ensure that the `amount` column must be strictly greater than zero.
```sql
ALTER TABLE PAYMENT ADD CONSTRAINT check_payment_amount CHECK (amount > 0);
```

**Violation test — inserting a zero amount:**
```sql
INSERT INTO PAYMENT (payment_id, bill_id, payment_method, payment_time, amount)
VALUES (999, 1, 'Cash', CURRENT_TIMESTAMP, 0);
```

![Constraint 2 - Check Payment Amount Error](docs/constraint_2.jpg)

> ❌ The database correctly rejects the insertion with: `ERROR: new row for relation "payment" violates check constraint "check_payment_amount"`

---

### Constraint 3 — Discount Percentage Must Be Between 0 and 100 (`DISCOUNT` table)

> **ALTER TABLE change:** A `CHECK` constraint named `check_percentage` was added to the `DISCOUNT` table to prevent discount percentages above 100% or below 0%.
```sql
ALTER TABLE DISCOUNT ADD CONSTRAINT check_percentage CHECK (percentage BETWEEN 0 AND 100);
```

**Violation test — inserting a percentage of 150:**
```sql
INSERT INTO DISCOUNT (discount_id, discount_name, percentage, valid_from, valid_to)
VALUES (999, 'Super Promo', 150.00, '2025-01-01', '2025-12-31');
```

![Constraint 3 - Check Percentage Error](docs/constraint_3.jpg)

> ❌ The database correctly rejects the insertion with: `ERROR: new row for relation "discount" violates check constraint "check_percentage"`

---

## 💾 Stage 2 — Backup & Restore Verification

A new backup of the `restaurant_db` database was performed after all Stage 2 operations (queries, updates, deletes, constraints) to ensure data integrity is preserved.

The pgAdmin job history confirms both the **Backup** and **Restore** operations completed successfully.

![Backup & Restore History - Stage 2](docs/backup_2.jpg)

---

## 🔄 Transactions — ROLLBACK & COMMIT

---

### ROLLBACK Example — Undoing a Bulk Discount Update

> This transaction demonstrates the `ROLLBACK` mechanism. A bulk update sets `discount_amount = 10.00` for all bills. The transaction is then rolled back, restoring the original values.
```sql
-- Step 1: View initial state
SELECT bill_id, total_amount, tax, discount_amount FROM BILL;

BEGIN;

-- Step 2: Update all bills — set discount to 10.00
UPDATE BILL
SET discount_amount = 10.00
RETURNING *;

-- Step 3: View state after update
SELECT bill_id, total_amount, tax, discount_amount FROM BILL;

-- Step 4: Cancel the update
ROLLBACK;

-- Step 5: View state after rollback (original values restored)
SELECT bill_id, total_amount, tax, discount_amount FROM BILL;
```

**State after UPDATE (before ROLLBACK) — all discount_amount = 10.00:**

![Rollback - State After Update](docs/rollback.jpg)

**State after ROLLBACK — original values restored:**

![State after ROLLBACK - original values restored](docs/discount_before.jpg)

---

### COMMIT Example — Permanently Extending Discount Validity

> This transaction demonstrates the `COMMIT` mechanism. A bulk update extends all discount `valid_to` dates by 1 month. The transaction is then committed, making the changes permanent.
```sql
-- Step 1: View initial state
SELECT discount_id, discount_name, percentage, valid_to FROM DISCOUNT;

BEGIN;

-- Step 2: Extend all discounts by 1 month
UPDATE DISCOUNT
SET valid_to = valid_to + INTERVAL '1 month'
RETURNING *;

-- Step 3: View state after update
SELECT discount_id, discount_name, percentage, valid_to FROM DISCOUNT;

-- Step 4: Confirm permanently
COMMIT;

-- Step 5: View state after commit (changes are permanent)
SELECT discount_id, discount_name, percentage, valid_to FROM DISCOUNT;
```

**Initial state — before transaction:**

![Commit - Initial State](docs/discount_before.jpg)

**Final state — after COMMIT (valid_to extended by 1 month):**

![Commit - After Commit](docs/commit_transactions.jpg)



## 🐳 Docker Setup (PostgreSQL)

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

### 1. Create your `.env` file

```env
POSTGRES_DB=restaurant_db
POSTGRES_USER=admin
POSTGRES_PASSWORD=admin123
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
```

### 2. Start the database

```bash
docker-compose up -d
```

### 3. Verify the container is running

```bash
docker ps
```

### 4. Connect to the database

```bash
docker exec -it restaurant_db psql -U admin -d restaurant_db
```

### 5. Stop the database

```bash
docker-compose down          # stop (keeps data)
docker-compose down -v       # stop + delete all data
```

---

## 🚀 Getting Started (Python App)

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd DB_5786_0000
   ```

2. **Start the database**
   ```bash
   docker-compose up -d
   ```

3. **Set up the Python environment**
   ```bash
   python -m venv venv
   source venv/bin/activate      # macOS / Linux
   # venv\Scripts\activate       # Windows
   pip install -r requirements.txt
   ```

4. **Run the application**
   ```bash
   python main.py
   ```

---

## ⚙️ Technologies

- **Database**: PostgreSQL 16 (via Docker)
- **Container**: Docker / Docker Compose
- **Application Layer**: Python
- **Mock Data**: Mockaroo, Python script
- **Version Control**: Git

---

<br><br>

# 🔗 Stage 3 – Integration and Views

📜 This stage focuses on integrating the **Order & Billing Department** database with the **Customer / Reservations / Loyalty Department** database — a crucial component of the overall restaurant management system. The objective is to build a unified structure that enables a comprehensive view of customer-related information, combining both transactional (orders, bills, payments) and relational (reservations, loyalty, feedback) data.

As part of this integration, SQL views were created from both the perspective of our department and the collaborating department, plus a third integrated view crossing both worlds. These views provide streamlined, role-specific access to the combined data, making it easier for each side to retrieve and analyze the information most relevant to their operational needs.

---

## 📜 ERD and DSD Diagrams

### ERD (Order & Billing — our department)
![ERD](docs/ERD.png)

### DSD (Order & Billing — our department)
![DSD](docs/DSD.png)

### ERD (Customer / Reservations / Loyalty — imported department)
![ERD](שלב_ג/group2-erd.png)

### DSD (Customer / Reservations / Loyalty — imported department)
![DSD](שלב_ג/group2-dsd.png)

### ERD (Integration)
![ERD](שלב_ג/merge_erd.png)

### DSD (Integration)
![DSD](שלב_ג/merge_dsd.png)

---

## 🔄 Reverse-Engineering Algorithm (DSD → ERD)

> The following algorithm is what was applied to the received `backup2.sql` to reconstruct the ERD of the imported department.

```
ALGORITHM : Reverse_Engineer_DSD_to_ERD
INPUT     : a PostgreSQL backup file (DDL + data)
OUTPUT    : an ERD diagram (entities, relationships, cardinalities)

STEP 1 — Extract tables (DSD)
   For each CREATE TABLE T:
       parse columns, types, CHECK, NOT NULL, UNIQUE
       parse PRIMARY KEY
       parse FOREIGN KEY (declared inline or via ALTER TABLE)

STEP 2 — Identify entities
   Each table T whose PK is NOT exclusively composed of 2 FKs
   becomes an entity in the ERD.

STEP 3 — Identify binary relationships
   For each FK on T(c) → T'(c'):
       create a relationship R between entity T and entity T'
       cardinality on T' side : "1" (FK references a PK)
       cardinality on T  side :
           - "1" if column c is UNIQUE      (1-to-1)
           - "N" otherwise                   (N-to-1)
       participation:
           - mandatory (solid line) if NOT NULL
           - optional (dashed line) if NULLABLE

STEP 4 — Identify N-N relationships
   If T is a junction table (PK = (FK1, FK2)):
       replace T with an N-to-N relationship between the 2 referenced entities.
       remaining columns of T become attributes of the relationship.

STEP 5 — Identify weak entities
   Entity E is weak if:
       - its PK contains a FK to another entity E'
       - its PK alone is not enough to identify it
   Represent E with a double-bordered rectangle and the identifying
   relationship with a double diamond.

STEP 6 — Restore attributes and their properties
   On each entity, draw simple attributes.
   Underline attributes that compose the PK.

STEP 7 — Verify consistency
   Cross-check the diagram against the backup data
   (e.g. SELECT COUNT(*) on each table, ensure no orphan relationships).
```

Applied to the received backup, the algorithm produced the following entities:

| Entity                | PK              | FKs                                | Type            |
|-----------------------|-----------------|------------------------------------|-----------------|
| `customer`            | `customer_id`   | —                                  | Strong          |
| `loyalty_tier`        | `tier_id`       | —                                  | Strong (lookup) |
| `reason`              | `reason_id`     | —                                  | Strong (lookup) |
| `status_type`         | `status_id`     | —                                  | Strong (lookup) |
| `loyalty`             | `loyalty_id`    | `customer_id` (UNIQUE), `tier_id`  | Strong, 1-1 with `customer` |
| `loyalty_transaction` | `transaction_id`| `loyalty_id`, `reason_id`          | Strong          |
| `reservation`         | `reservation_id`| `customer_id`, `status_id`         | Strong          |
| `feedback`            | `feedback_id`   | `reservation_id` (UNIQUE)          | Strong, 1-1 with `reservation` |
| `waitlist`            | `waitlist_id`   | `customer_id`, `status_id`         | Strong          |

---

## 🧠 Integration Decisions

- Integration was done using PostgreSQL's **`postgres_fdw`** foreign data wrapper to allow direct querying of the remote database.
- Remote tables were **mirrored** as foreign tables in the local database, then copied into newly created local tables via `INSERT INTO ... SELECT FROM ..._remote`.
- A single **bridge FK** was added: `"ORDER".customer_id → customer.customer_id` — the natural pivot between both departments.
- The local `"ORDER".customer_id` column had Mockaroo-generated values from 1 to 999 974, but only 500 customers exist. We **remapped invalid IDs** with `((customer_id - 1) % 500) + 1`, which uniformly distributes orders across the 500 existing customers without losing any rows.
- All CHECK / UNIQUE / FK constraints from the imported schema were **strictly preserved** in the local clones.
- Tables were imported in **dependency order** (lookups → `customer` → tables with FK to `customer`) so that foreign keys validate at insert time.
- Foreign tables were **dropped after integration** for cleanliness and security.

---

## 📝 Integration Process and SQL Commands

> The following key SQL commands were used in the integration process. Each command includes a short explanation of what it does and why it was used.

### 1. Enable the Foreign Data Wrapper

This extension allows PostgreSQL to access tables from another PostgreSQL database.

```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
```

---

### 2. Define the Connection to the Remote Server

This command creates a server definition pointing to the imported group's database.

```sql
CREATE SERVER other_group_server
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'localhost', dbname 'other_group_db', port '5432');
```

---

### 3. Create User Mapping for Authentication

This defines how the local user will connect to the remote database.

```sql
CREATE USER MAPPING FOR admin
SERVER other_group_server
OPTIONS (user 'admin', password 'admin123');
```

---

### 4. Mirror the Remote `customer` Table (example)

A foreign table is created that represents `customer` from the remote database.

```sql
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
```

---

### 5. Create the Real Local `customer` Table

```sql
CREATE TABLE customer (
    customer_id INT PRIMARY KEY,
    first_name  VARCHAR(50)  NOT NULL,
    last_name   VARCHAR(50)  NOT NULL,
    phone       VARCHAR(15)  NOT NULL UNIQUE,
    email       VARCHAR(100) NOT NULL UNIQUE,
    created_at  DATE         NOT NULL,
    is_active   INTEGER      DEFAULT 1,
    CONSTRAINT chk_names_different    CHECK (lower(first_name) <> lower(last_name)),
    CONSTRAINT customer_email_check   CHECK (email LIKE '%_@_%.__%'),
    CONSTRAINT customer_is_active_check CHECK (is_active IN (0, 1)),
    CONSTRAINT customer_phone_check   CHECK (length(phone) >= 7)
);
```

---

### 6. Copy Remote Data into Local Table

```sql
INSERT INTO customer (customer_id, first_name, last_name, phone, email, created_at, is_active)
SELECT customer_id, first_name, last_name, phone, email, created_at, is_active
FROM customer_remote;
```

> The same pattern is repeated for the 8 other imported tables (`loyalty_tier`, `reason`, `status_type`, `loyalty`, `loyalty_transaction`, `reservation`, `feedback`, `waitlist`), in dependency order.

---

### 7. Build the Integration Bridge — `"ORDER".customer_id → customer.customer_id`

This is the heart of the integration. We re-map invalid `customer_id` values and add the foreign key.

```sql
-- Re-map: Mockaroo had generated random IDs up to 999 974. Bring them all
-- into the range [1..500] so they all reference an existing customer.
UPDATE "ORDER"
SET    customer_id = ((customer_id - 1) % 500) + 1
WHERE  customer_id IS NOT NULL;

-- Now declare the foreign key
ALTER TABLE "ORDER"
ADD CONSTRAINT fk_order_customer
FOREIGN KEY (customer_id) REFERENCES customer(customer_id);
```

---

### 8. Clean-Up

After data was successfully copied, all foreign tables were dropped to finalize the integration.

```sql
DROP FOREIGN TABLE customer_remote;
DROP FOREIGN TABLE loyalty_tier_remote;
DROP FOREIGN TABLE reason_remote;
DROP FOREIGN TABLE status_type_remote;
DROP FOREIGN TABLE loyalty_remote;
DROP FOREIGN TABLE loyalty_transaction_remote;
DROP FOREIGN TABLE reservation_remote;
DROP FOREIGN TABLE feedback_remote;
DROP FOREIGN TABLE waitlist_remote;
```

---

### 9. Verification

After integration, the database contains **15 tables** and **~58 000 rows** with full referential integrity.

```
       table_name      | count
-----------------------+-------
 bill                  |   500
 bill_discount         | 18907
 customer              |   500
 discount              |   472
 feedback              |   429
 loyalty               |   500
 loyalty_tier          |     4
 loyalty_transaction   | 20000
 "ORDER"               |   500
 order_item            | 20000
 payment               |   499
 reason                |     8
 reservation           | 17118
 status_type           |     8
 waitlist              |   364
```

The full integration script is in [`שלב_ג/Integrate.sql`](שלב_ג/Integrate.sql).

---

## 👁️ Views and Analytical Queries

This section presents the **3 SQL views** created as part of Stage 3, providing analytical insights from each department's perspective and one integrated cross-department view. Each view is accompanied by a description, definition, and 2 analytical queries with results.

The full views script is in [`שלב_ג/Views.sql`](שלב_ג/Views.sql).

---

### 📘 View 1 – Order & Billing: `Customer_Order_Summary`

💡 **Description**:
For each customer, aggregates their commercial activity: number of orders, total billed amount, average bill, last order timestamp. Joins **3 tables** : `customer` + `"ORDER"` + `bill`.

```sql
CREATE VIEW Customer_Order_Summary AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    COUNT(DISTINCT o.order_id)                 AS total_orders,
    COALESCE(SUM(b.final_amount), 0)           AS total_spent,
    COALESCE(ROUND(AVG(b.final_amount), 2), 0) AS avg_bill_amount,
    MAX(o.order_time)                          AS last_order_time
FROM       customer c
LEFT JOIN  "ORDER" o ON c.customer_id = o.customer_id
LEFT JOIN  bill    b ON o.order_id    = b.order_id
GROUP BY   c.customer_id, c.first_name, c.last_name, c.email;
```

📷 _Sample of the view (first 10 rows)_:

```
 customer_id |   customer_name   |             email             | total_orders | total_spent | avg_bill_amount |   last_order_time
-------------+-------------------+-------------------------------+--------------+-------------+-----------------+---------------------
           1 | Forrest Greatbach | fgreatbach0@freewebs.com      |            1 |       36.00 |           36.00 | 2023-10-28 12:30:00
           2 | Aleksandr Ring    | aring1@vistaprint.com         |            2 |      170.55 |           85.28 | 2024-04-12 00:00:00
           3 | Fallon Stabbins   | fstabbins2@chicagotribune.com |            1 |      683.02 |          683.02 | 2023-10-28 19:15:00
           4 | Allx Yakushkev    | ayakushkev3@yolasite.com      |            0 |        0.00 |            0.00 |
           5 | Welsh Phillpotts  | wphillpotts4@ustream.tv       |            1 |        0.00 |            0.00 | 2024-04-26 00:00:00
           6 | Konstance Buxsey  | kbuxsey5@gmpg.org             |            0 |        0.00 |            0.00 |
           7 | Jerrilyn Uccelli  | juccelli6@bravesites.com      |            2 |     1195.16 |          597.58 | 2024-03-21 00:00:00
           8 | Ilene Raincin     | iraincin7@prweb.com           |            0 |        0.00 |            0.00 |
           9 | Phylys Jamieson   | pjamieson8@wp.com             |            0 |        0.00 |            0.00 |
          10 | Erl Berth         | eberth9@globo.com             |            1 |      357.47 |          357.47 | 2024-03-13 00:00:00
```

---

#### 🔍 Query 1.1 – Top 10 customers by revenue

💡 **Purpose**: Identify the highest-spending customers for VIP programs or premium offers.

```sql
SELECT customer_name, total_orders, total_spent, last_order_time
FROM   Customer_Order_Summary
WHERE  total_orders > 0
ORDER BY total_spent DESC
LIMIT 10;
```

📷 _Result_:

```
    customer_name    | total_orders | total_spent |   last_order_time
---------------------+--------------+-------------+---------------------
 Etta Johnes         |            4 |     2816.98 | 2024-03-29 00:00:00
 Ase Fellini         |            5 |     2726.18 | 2024-04-17 00:00:00
 Cordey Monson       |            5 |     2512.86 | 2024-04-26 00:00:00
 Kitty Wasielewicz   |            3 |     2368.26 | 2024-04-26 00:00:00
 Kienan Nairns       |            3 |     2310.30 | 2024-04-16 00:00:00
 Karon Johnsee       |            3 |     2264.16 | 2024-04-23 00:00:00
 Leupold Piddletown  |            3 |     1997.02 | 2024-04-28 00:00:00
 Niels Ivanin        |            4 |     1947.00 | 2024-04-29 00:00:00
 Clementius Whiteson |            3 |     1896.67 | 2024-04-18 00:00:00
 Clem Brunsdon       |            3 |     1892.70 | 2024-05-02 00:00:00
```

---

#### 🔍 Query 1.2 – Inactive customers (never ordered)

💡 **Purpose**: Spot customers who registered but never converted to a purchase, for targeted marketing.

```sql
SELECT customer_id, customer_name, email
FROM   Customer_Order_Summary
WHERE  total_orders = 0
ORDER BY customer_id
LIMIT 10;
```

📷 _Result_:

```
 customer_id |    customer_name    |            email
-------------+---------------------+------------------------------
           4 | Allx Yakushkev      | ayakushkev3@yolasite.com
           6 | Konstance Buxsey    | kbuxsey5@gmpg.org
           8 | Ilene Raincin       | iraincin7@prweb.com
           9 | Phylys Jamieson     | pjamieson8@wp.com
          11 | Ralph Zimmermeister | rzimmermeistera@freewebs.com
          12 | Gilligan Housen     | ghousenb@lycos.com
          14 | Sashenka Peart      | speartd@sbwire.com
          20 | Ashton Tillot       | atillotj@sitemeter.com
          23 | Isa Dutson          | idutsonm@cam.ac.uk
          24 | Florella Vankeev    | fvankeevn@google.com
```

---

### 📘 View 2 – Customer / Loyalty: `Customer_Loyalty_Status`

💡 **Description**:
For each customer, exposes their current loyalty status: tier (Bronze/Silver/Gold/Platinum), points balance, number of point transactions and number of past reservations. Joins **4 tables**: `customer` + `loyalty` + `loyalty_tier` + `reservation` (plus `loyalty_transaction` for the count).

```sql
CREATE VIEW Customer_Loyalty_Status AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name           AS customer_name,
    COALESCE(lt.level, 'No Loyalty')             AS tier_level,
    COALESCE(l.points, 0)                        AS current_points,
    COUNT(DISTINCT lx.transaction_id)            AS loyalty_tx_count,
    COUNT(DISTINCT r.reservation_id)             AS total_reservations,
    MAX(r.datetime)                              AS last_reservation_date
FROM        customer c
LEFT JOIN   loyalty             l  ON c.customer_id = l.customer_id
LEFT JOIN   loyalty_tier        lt ON l.tier_id     = lt.tier_id
LEFT JOIN   loyalty_transaction lx ON l.loyalty_id  = lx.loyalty_id
LEFT JOIN   reservation         r  ON c.customer_id = r.customer_id
GROUP BY    c.customer_id, c.first_name, c.last_name, lt.level, l.points;
```

📷 _Sample of the view (first 10 rows)_:

```
 customer_id |   customer_name   | tier_level | current_points | loyalty_tx_count | total_reservations | last_reservation_date
-------------+-------------------+------------+----------------+------------------+--------------------+-----------------------
           1 | Forrest Greatbach | Silver     |           3265 |               55 |                 38 | 2025-02-03
           2 | Aleksandr Ring    | Bronze     |           1838 |               38 |                 47 | 2024-12-31
           3 | Fallon Stabbins   | Bronze     |           1159 |               42 |                 39 | 2025-02-14
           4 | Allx Yakushkev    | Silver     |           4422 |               30 |                 44 | 2024-12-30
           5 | Welsh Phillpotts  | Gold       |           7281 |               45 |                 31 | 2025-01-21
           6 | Konstance Buxsey  | Platinum   |           8813 |               45 |                 38 | 2025-01-28
           7 | Jerrilyn Uccelli  | Silver     |           4638 |               42 |                 37 | 2025-01-30
           8 | Ilene Raincin     | Silver     |           4041 |               46 |                 35 | 2024-12-15
           9 | Phylys Jamieson   | Silver     |           3328 |               29 |                 38 | 2024-12-18
          10 | Erl Berth         | Platinum   |           9756 |               39 |                 34 | 2025-01-01
```

---

#### 🔍 Query 2.1 – Distribution of customers by loyalty tier

💡 **Purpose**: Verify the balance of the loyalty program (too many Bronze? not enough Platinum?).

```sql
SELECT tier_level,
       COUNT(*)                          AS nb_customers,
       ROUND(AVG(current_points), 0)     AS avg_points,
       ROUND(AVG(total_reservations), 1) AS avg_reservations
FROM   Customer_Loyalty_Status
GROUP BY tier_level
ORDER BY CASE tier_level
    WHEN 'Bronze'   THEN 1
    WHEN 'Silver'   THEN 2
    WHEN 'Gold'     THEN 3
    WHEN 'Platinum' THEN 4
    ELSE 5 END;
```

📷 _Result_:

```
 tier_level | nb_customers | avg_points | avg_reservations
------------+--------------+------------+------------------
 Bronze     |          118 |       1287 |             33.9
 Silver     |          117 |       3781 |             34.2
 Gold       |          128 |       6283 |             34.4
 Platinum   |          137 |       8809 |             34.3
```

---

#### 🔍 Query 2.2 – Top 10 most loyal customers (by points)

💡 **Purpose**: Reward highly-engaged customers (points + reservations).

```sql
SELECT customer_name, tier_level, current_points, total_reservations, last_reservation_date
FROM   Customer_Loyalty_Status
ORDER BY current_points DESC, total_reservations DESC
LIMIT 10;
```

📷 _Result_:

```
   customer_name   | tier_level | current_points | total_reservations | last_reservation_date
-------------------+------------+----------------+--------------------+-----------------------
 Peterus Elizabeth | Platinum   |           9962 |                 35 | 2024-11-25
 Papagena Praill   | Platinum   |           9961 |                 49 | 2025-01-31
 Gannon Norrey     | Platinum   |           9953 |                 34 | 2025-02-17
 Dorena Laurie     | Platinum   |           9936 |                 40 | 2025-02-19
 Marianne Gallyon  | Platinum   |           9931 |                 31 | 2025-01-14
 Wilhelm Gillyett  | Platinum   |           9895 |                 42 | 2024-12-09
 Spencer Ruffy     | Platinum   |           9874 |                 30 | 2025-01-08
 Nefen Veronique   | Platinum   |           9849 |                 31 | 2025-01-21
 Raven Scones      | Platinum   |           9836 |                 31 | 2024-11-29
 Mathilde Phelips  | Platinum   |           9820 |                 39 | 2025-01-25
```

---

### 📘 View 3 – Cross-Department: `Customer_Cross_Activity`

💡 **Description**:
Crosses both worlds: number of reservations (Customer/Loyalty side) and number of orders + revenue (Order/Billing side), enriched with the loyalty tier, plus a categorized `engagement_type`. Joins **6 tables**: `customer` + `loyalty` + `loyalty_tier` + `reservation` + `"ORDER"` + `bill`.

> **Technical note**: We use `LATERAL` subqueries to pre-aggregate orders and reservations independently. This avoids the cartesian product (each bill multiplied by each reservation per customer) that would otherwise inflate `total_revenue`.

```sql
CREATE VIEW Customer_Cross_Activity AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name              AS customer_name,
    COALESCE(lt.level, 'No Loyalty')                AS tier_level,
    res.nb_reservations,
    ord.nb_orders,
    ord.total_revenue,
    CASE
        WHEN ord.nb_orders   = 0 AND res.nb_reservations > 0 THEN 'Reservation only'
        WHEN ord.nb_orders   > 0 AND res.nb_reservations = 0 THEN 'Order only'
        WHEN ord.nb_orders   > 0 AND res.nb_reservations > 0 THEN 'Both'
        ELSE 'Inactive'
    END                                             AS engagement_type
FROM        customer c
LEFT JOIN   loyalty      l  ON c.customer_id = l.customer_id
LEFT JOIN   loyalty_tier lt ON l.tier_id     = lt.tier_id
LEFT JOIN LATERAL (
    SELECT COUNT(*) AS nb_reservations
    FROM   reservation r
    WHERE  r.customer_id = c.customer_id
) res ON TRUE
LEFT JOIN LATERAL (
    SELECT COUNT(*)                         AS nb_orders,
           COALESCE(SUM(b.final_amount), 0) AS total_revenue
    FROM   "ORDER" o
    LEFT JOIN bill b ON o.order_id = b.order_id
    WHERE  o.customer_id = c.customer_id
) ord ON TRUE;
```

📷 _Sample of the view (first 10 rows)_:

```
 customer_id |   customer_name   | tier_level | nb_reservations | nb_orders | total_revenue | engagement_type
-------------+-------------------+------------+-----------------+-----------+---------------+------------------
           1 | Forrest Greatbach | Silver     |              38 |         1 |         36.00 | Both
           2 | Aleksandr Ring    | Bronze     |              47 |         2 |        170.55 | Both
           3 | Fallon Stabbins   | Bronze     |              39 |         1 |        683.02 | Both
           4 | Allx Yakushkev    | Silver     |              44 |         0 |          0.00 | Reservation only
           5 | Welsh Phillpotts  | Gold       |              31 |         1 |          0.00 | Both
           6 | Konstance Buxsey  | Platinum   |              38 |         0 |          0.00 | Reservation only
           7 | Jerrilyn Uccelli  | Silver     |              37 |         2 |       1195.16 | Both
           8 | Ilene Raincin     | Silver     |              35 |         0 |          0.00 | Reservation only
           9 | Phylys Jamieson   | Silver     |              38 |         0 |          0.00 | Reservation only
          10 | Erl Berth         | Platinum   |              34 |         1 |        357.47 | Both
```

---

#### 🔍 Query 3.1 – Distribution by engagement type

💡 **Purpose**: Measure the reservation→order conversion rate.

```sql
SELECT engagement_type,
       COUNT(*)                       AS nb_customers,
       ROUND(AVG(total_revenue), 2)   AS avg_revenue,
       ROUND(AVG(nb_reservations), 1) AS avg_reservations,
       ROUND(AVG(nb_orders), 1)       AS avg_orders
FROM   Customer_Cross_Activity
GROUP BY engagement_type
ORDER BY nb_customers DESC;
```

📷 _Result_:

```
 engagement_type  | nb_customers | avg_revenue | avg_reservations | avg_orders
------------------+--------------+-------------+------------------+------------
 Both             |          321 |      608.27 |             34.4 |        1.6
 Reservation only |          179 |        0.00 |             34.0 |        0.0
```

📊 **Reading**: 321 customers (64 %) are active on both sides; 179 customers reserved but never ordered — an ideal target for a welcome coupon to redeem on-site.

---

#### 🔍 Query 3.2 – Engagement and average revenue per loyalty tier

💡 **Purpose**: Verify the correlation between Platinum status and actual revenue generated.

```sql
SELECT tier_level,
       COUNT(*)                       AS nb_customers,
       ROUND(AVG(nb_reservations), 1) AS avg_reservations,
       ROUND(AVG(nb_orders), 1)       AS avg_orders,
       ROUND(AVG(total_revenue), 2)   AS avg_revenue
FROM   Customer_Cross_Activity
GROUP BY tier_level
ORDER BY avg_revenue DESC;
```

📷 _Result_:

```
 tier_level | nb_customers | avg_reservations | avg_orders | avg_revenue
------------+--------------+------------------+------------+-------------
 Silver     |          117 |             34.2 |        1.1 |      457.99
 Platinum   |          137 |             34.3 |        1.1 |      397.56
 Bronze     |          118 |             33.9 |        0.9 |      360.95
 Gold       |          128 |             34.4 |        1.0 |      348.53
```

📊 **Reading**: Surprisingly, Silver customers generate slightly more revenue on average (458 $) than Platinum (398 $). In the generated dataset, the tier seems more correlated with retention than transactional value — in a real system, the tier thresholds would need adjustment.

---

## ✅ Stage 3 — Conclusion

In this integration stage, we:

- Connected two separate departments (Order & Billing + Customer / Reservations / Loyalty) using PostgreSQL's `postgres_fdw` foreign data wrapper as the transfer bridge.
- Imported 9 tables and ~38 000 rows of remote data into the local database with strict referential integrity.
- Established a single **integration FK** (`"ORDER".customer_id → customer.customer_id`) materializing the cross-department link in the schema itself.
- Re-mapped invalid Mockaroo-generated customer IDs to maintain FK validity without losing rows.
- Created **3 SQL views** providing analytical insights from each department's perspective and a third integrated view that fully exploits the cross-department fusion.
- Demonstrated the use of `LATERAL` subqueries to handle multi-table aggregations correctly, avoiding cartesian products.

The result is a unified database of **15 tables** and **~58 000 rows** offering a 360° view of every customer.

---

## 📦 Stage 3 deliverables (in `שלב_ג/`)

| File | Purpose |
|------|---------|
| `Integrate.sql` | Full FDW-based integration script (5 phases) |
| `Views.sql` | 3 views + 6 analytical queries |
| `backup3.sql` | Full dump of `restaurant_db` after integration |
| `merge_dsd.png` / `merge_erd.png` | Integrated schema diagrams |
| `group2-dsd.png` / `group2-erd.png` | Imported department diagrams |
| `*.erdplus` | Editable ERDPlus sources for each diagram |
| `restore_other_group_db.sh` | Script to restore the received backup into `other_group_db` |
| `דוח_פרויקט_שלב_ג.md` | Stand-alone French project report |

---

## 📄 License

This project is for academic purposes only.
