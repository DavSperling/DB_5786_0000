# DB_5786_0000 — Restaurant Order & Billing Database

> **Academic Mini-Project | 3rd Year — 2nd Semester**  
> Database Design & Implementation

---

## 📋 Project Overview

This project implements a relational database system for managing **restaurant orders, billing, payments, and discounts**.  
It covers the full database design lifecycle — from the conceptual Entity-Relationship (ER) model down to the relational schema — and is built using **Python** as the application layer.

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

### Relational Schema

> 📁 Save the image as `docs/relational_schema.png`

![Relational Schema](docs/relational_schema.png)

### Entity-Relationship (ER) Diagram

> 📁 Save the image as `docs/er_diagram.png`

![ER Diagram](docs/er_diagram.png)

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
│   ├── relational_schema.png   # Relational table diagram
│   └── er_diagram.png          # Entity-Relationship diagram
├── .gitignore
└── README.md
```

---

## ⚙️ Technologies

- **Database**: Relational model (SQL)
- **Application Layer**: Python
- **Version Control**: Git

---

## 🚀 Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd DB_5786_0000
   ```

2. **Set up the Python environment**
   ```bash
   python -m venv venv
   source venv/bin/activate      # macOS / Linux
   # venv\Scripts\activate       # Windows
   pip install -r requirements.txt
   ```

3. **Initialize the database**
   ```bash
   python setup_db.py
   ```

4. **Run the application**
   ```bash
   python main.py
   ```

---

## 👤 Author

**David** — Mahon Lev, 3rd Year  
2nd Semester Mini-Project — Database Design

---

## 📄 License

This project is for academic purposes only.