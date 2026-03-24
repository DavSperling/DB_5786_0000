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

## 📄 License

This project is for academic purposes only.
