# La Bella Cucina OS — Setup & Launch Instructions

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Python | ≥ 3.11 | Run the GUI |
| Docker Desktop | any | Host PostgreSQL |
| pip | any | Install Python packages |

---

## Step 1 — Start the database

From the **project root** (`DB_5786_0000/`):

```bash
docker-compose up -d
```

Wait ~10 seconds for PostgreSQL to be ready.  
Verify: `docker ps` should show **PostgreSQL_DB** running on port **5433**.

---

## Step 2 — Install Python dependencies

```bash
cd שלב_ה/gui
pip install -r requirements.txt
```

Or with a virtual environment (recommended):

```bash
python -m venv .venv
source .venv/bin/activate        # macOS / Linux
# .venv\Scripts\activate.bat     # Windows
pip install -r requirements.txt
```

---

## Step 3 — Launch the application

```bash
python main.py
```

The login window opens immediately.

---

## Login credentials

| Username | Password   |
|----------|------------|
| admin    | admin123   |
| manager  | manager123 |

---

## Application screens

| Screen | Description |
|--------|-------------|
| Dashboard | Live stats — counts, order statuses, revenue |
| Orders | Full CRUD on the ORDER table |
| Order Items | Full CRUD on ORDER_ITEM |
| Bills | Full CRUD on BILL |
| Payments | Full CRUD on PAYMENT |
| Discounts | Full CRUD on DISCOUNT |
| Customers | Read-only views — customer summary, loyalty, reservations, waitlist, feedback |
| Queries | Run 6 Stage 2 SELECT queries with parameters |
| Programs | Run F1, F2 (functions) and P1, P2 (procedures) from Stage 4 |

---

## How the Update flow works

1. Navigate to the desired table screen (e.g. Orders).
2. Click the **Update** tab in the right panel.
3. Enter the primary key in the top field and click **Load**.
4. The system fetches the row and populates all fields.
5. Edit the fields you want to change.
6. Click **Update** to save.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Cannot connect to the database" | Run `docker-compose up -d` in the project root |
| `ModuleNotFoundError: customtkinter` | Run `pip install -r requirements.txt` |
| `ModuleNotFoundError: psycopg2` | Run `pip install psycopg2-binary` |
| Port 5433 in use | Edit `DB_PORT` in `.env` and `docker-compose.yml` |
| P1 errors about `discount_amount` | The BILL table uses `discount`; the app detects this automatically |

---

## Database connection settings

Defaults (from `.env`):

```
Host:     localhost
Port:     5433
Database: restaurant_db
User:     admin
Password: admin123
```

Override by editing `.env` in the project root before launching.
