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

1. [Overview](#overview)
2. [Application Mockup (UI)](#application-mockup-ui)
3. [ERD and DSD Diagrams](#erd-and-dsd-diagrams)
4. [Data Structure Description](#data-structure-description)
5. [Data Insertion Methods](#data-insertion-methods)
6. [Backup & Restore](#backup--restore)
7. [Docker Setup](#docker-setup-postgresql)
8. [Getting Started](#getting-started-python-app)

---

## 🧾 Overview

This database system is designed to manage the operational and financial activities of a restaurant. It includes data about orders, order items, bills, payments, discounts, and billing history.

The system uses foreign keys, weak entities, and entity relationships to maintain data consistency and avoid redundancy.

---

## 🖥️ Application Mockup (UI)

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

## 🗂️ ERD and DSD Diagrams

### ERD
![ER Diagram](docs/ERD.png)

### DSD
![Relational Schema](docs/DSD.png)

---

## 🗃️ Data Structure Description

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
