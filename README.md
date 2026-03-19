# DB_5786_0000 — Restaurant Order & Billing Database

> **Academic Mini-Project | 3rd Year — 2nd Semester**
> Database Design & Implementation

---

## 📋 Project Overview

This project implements a relational database system for managing **restaurant orders, billing, payments, and discounts**.
It covers the full database design lifecycle — from the conceptual Entity-Relationship (ER) model down to the relational schema — and is built using **Python** as the application layer.

The screenshots below represent a **UI mockup** of what the application layer could look like, designed to illustrate the real-world use case of the database.

---

## 🖥️ Application Mockup

### Login
![Login Screen](docs/login.jpeg)

---

### Dashboard
![Dashboard](docs/dashboard.jpeg)

---

### Orders & Billing
![Orders and Billing](docs/order_and_bill.jpeg)

---

### Menu Management
![Menu Management](docs/menu_management.jpeg)

---

### Staff & Tables
![Staff and Table Map](docs/staff_table.jpeg)

---

## 🗂️ Database Schema

The database is composed of the following **6 tables**:

| Table | Description |
|---|---|
| `ORDER` | Stores customer orders (status, time, waiter, customer) |
| `ORDER_ITEM` | Each item within an order (quantity, special request, menu item) |
| `BILL` | The bill generated per order (total amount, tax, discount, final amount) |
| `PAYMENT` | Payment record linked to a bill (method, time, amount) |
| `DISCOUNT` | Available discounts (name, percentage, validity dates) |
| `BILL_DISCOUNT` | Junction table linking bills to applied discounts |

### Relational Schema (DSD)

![Relational Schema](docs/DSD.png)

### Entity-Relationship Diagram (ERD)

![ER Diagram](docs/ERD.png)

---

## 🔗 Relationships

- An **Order** contains one or more **Order Items** (each linked to a menu item).
- An **Order** generates exactly one **Bill**.
- A **Bill** is paid via one **Payment**.
- A **Bill** can have zero or more **Discounts** applied through the **Bill_Discount** junction table.
- A **Discount** can be applied to multiple bills.

---

## 🏗️ Project Structure

```
DB_5786_0000/
├── docs/
│   ├── DSD.png                 # Relational schema diagram
│   ├── ERD.png                 # Entity-Relationship diagram
│   ├── login.jpeg              # UI Mockup — Login screen
│   ├── dashboard.jpeg          # UI Mockup — Dashboard
│   ├── order_and_bill.jpeg     # UI Mockup — Orders & Billing
│   ├── menu_management.jpeg    # UI Mockup — Menu Management
│   └── staff_table.jpeg        # UI Mockup — Staff & Tables
├── sql/
│   └── init.sql                # Database creation & seed script
├── .env                        # Environment variables (git-ignored)
├── docker-compose.yml          # Docker PostgreSQL setup
├── .gitignore
└── README.md
```

---

## ⚙️ Technologies

- **Database**: PostgreSQL 16 (via Docker)
- **Container**: Docker / Docker Compose
- **Application Layer**: Python
- **Version Control**: Git

---

## 🐳 Docker Setup (PostgreSQL)

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

### 1. Create your `.env` file

The `.env` file is already provided. Edit it if you want to change credentials:

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

PostgreSQL will start and automatically run `sql/init.sql` to create all tables.

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

## 👤 Author

**David and Dylan** — Mahon Lev, 3rd Year
2nd Semester Mini-Project — Database Design

---

## 📄 License

This project is for academic purposes only.
