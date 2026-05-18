"""Stage 2 query runner — exposes 4 SELECT queries with optional parameters."""
from tkinter import messagebox
import customtkinter as ctk
from .widgets import make_tree, section_header
from config import COLORS

# Each entry: (display_name, description, sql_template, param_fields)
# param_fields: list of (label, placeholder, type_cast)
QUERIES = [
    (
        'Q1 – Orders with Billing & Payment',
        'Shows each order joined to its bill and payment, sorted by total amount.',
        """
        SELECT o.order_id,
               COALESCE(c.first_name||' '||c.last_name,'Unknown') AS customer,
               o.order_status,
               TO_CHAR(o.order_time,'YYYY-MM-DD HH24:MI') AS order_time,
               b.total_amount,
               b.tax,
               p.payment_method
        FROM "ORDER" o
        JOIN bill b    ON o.order_id = b.order_id
        JOIN payment p ON b.bill_id  = p.bill_id
        LEFT JOIN customer c ON o.customer_id = c.customer_id
        ORDER BY b.total_amount DESC
        LIMIT %s
        """,
        [('Max rows', '100', int)]
    ),
    (
        'Q2 – Bills with Discounts',
        'Bills that have at least one discount applied, showing savings.',
        """
        SELECT b.bill_id,
               COALESCE(c.first_name||' '||c.last_name,'Unknown') AS customer,
               b.total_amount,
               d.discount_name,
               d.percentage,
               ROUND(b.total_amount * d.percentage / 100, 2) AS amount_saved
        FROM bill b
        JOIN bill_discount bd ON b.bill_id    = bd.bill_id
        JOIN discount d       ON bd.discount_id = d.discount_id
        JOIN "ORDER" o        ON b.order_id   = o.order_id
        LEFT JOIN customer c  ON o.customer_id = c.customer_id
        ORDER BY amount_saved DESC
        LIMIT %s
        """,
        [('Max rows', '100', int)]
    ),
    (
        'Q3 – Waiter Monthly Performance',
        'Revenue and order count per waiter per month.',
        """
        SELECT o.waiter_id AS waiter,
               EXTRACT(YEAR  FROM o.order_time)::INT AS year,
               EXTRACT(MONTH FROM o.order_time)::INT AS month,
               COUNT(o.order_id)     AS total_orders,
               COALESCE(SUM(b.total_amount),0)::NUMERIC(12,2) AS revenue
        FROM "ORDER" o
        JOIN bill b ON o.order_id = b.order_id
        WHERE EXTRACT(YEAR FROM o.order_time)::INT = %s
        GROUP BY o.waiter_id,
                 EXTRACT(YEAR FROM o.order_time),
                 EXTRACT(MONTH FROM o.order_time)
        ORDER BY year, month, revenue DESC
        """,
        [('Year', '2024', int)]
    ),
    (
        'Q4 – Payment Method Statistics',
        'Usage count and total paid per payment method per month.',
        """
        SELECT p.payment_method,
               EXTRACT(YEAR  FROM p.payment_time)::INT AS year,
               EXTRACT(MONTH FROM p.payment_time)::INT AS month,
               COUNT(p.payment_id)  AS usage_count,
               SUM(p.amount)::NUMERIC(12,2) AS total_paid
        FROM payment p
        JOIN bill b ON p.bill_id = b.bill_id
        WHERE EXTRACT(YEAR FROM p.payment_time)::INT = %s
        GROUP BY p.payment_method,
                 EXTRACT(YEAR FROM p.payment_time),
                 EXTRACT(MONTH FROM p.payment_time)
        ORDER BY year, month, usage_count DESC
        """,
        [('Year', '2024', int)]
    ),
    (
        'Q5 – Daily Revenue Report',
        'Total revenue and tax collected per day.',
        """
        SELECT EXTRACT(YEAR  FROM b.bill_time)::INT AS year,
               EXTRACT(MONTH FROM b.bill_time)::INT AS month,
               EXTRACT(DAY   FROM b.bill_time)::INT AS day,
               COUNT(b.bill_id)                     AS bills,
               SUM(b.total_amount)::NUMERIC(12,2)   AS daily_revenue,
               SUM(b.tax)::NUMERIC(12,2)             AS daily_tax
        FROM bill b
        WHERE EXTRACT(YEAR FROM b.bill_time)::INT = %s
        GROUP BY EXTRACT(YEAR FROM b.bill_time),
                 EXTRACT(MONTH FROM b.bill_time),
                 EXTRACT(DAY FROM b.bill_time)
        ORDER BY year DESC, month DESC, day DESC
        """,
        [('Year', '2024', int)]
    ),
    (
        'Q6 – Cancelled Orders with Items',
        'All cancelled orders and their line items.',
        """
        SELECT o.order_id,
               COALESCE(c.first_name||' '||c.last_name,'Unknown') AS customer,
               TO_CHAR(o.order_time,'YYYY-MM-DD HH24:MI') AS order_time,
               'Waiter #'||o.waiter_id AS waiter,
               oi.menu_item_id         AS item_id,
               oi.quantity
        FROM "ORDER" o
        JOIN order_item oi ON o.order_id    = oi.order_id
        LEFT JOIN customer c ON o.customer_id = c.customer_id
        WHERE o.order_status = 'Cancelled'
        ORDER BY o.order_time DESC
        LIMIT %s
        """,
        [('Max rows', '200', int)]
    ),
]


class QueriesScreen(ctk.CTkFrame):
    def __init__(self, parent, db):
        super().__init__(parent, fg_color='transparent')
        self._db = db
        self._build()

    def refresh(self):
        pass

    def _build(self):
        section_header(self, '🔍', 'Stage 2 – Query Runner')

        # Top panel: query selector + params + run button
        top = ctk.CTkFrame(self, fg_color=COLORS['card_bg'], corner_radius=12)
        top.pack(fill='x', padx=22, pady=(0, 8))

        sel_row = ctk.CTkFrame(top, fg_color='transparent')
        sel_row.pack(fill='x', padx=14, pady=(12, 4))

        ctk.CTkLabel(sel_row, text='Query:', text_color=COLORS['text_dim'],
                     width=56).pack(side='left')
        self._q_sel = ctk.CTkOptionMenu(
            sel_row, values=[q[0] for q in QUERIES],
            width=380, dynamic_resizing=False,
            command=self._on_query_change
        )
        self._q_sel.set(QUERIES[0][0])
        self._q_sel.pack(side='left', padx=8)

        ctk.CTkButton(sel_row, text='▶  Run Query', height=36,
                       fg_color=COLORS['primary'], hover_color=COLORS['primary_hov'],
                       command=self._run).pack(side='right', padx=14)

        self._desc_lbl = ctk.CTkLabel(top, text=QUERIES[0][1],
                                       text_color=COLORS['text_dim'],
                                       font=ctk.CTkFont(size=11), anchor='w')
        self._desc_lbl.pack(fill='x', padx=14, pady=(0, 6))

        # Param row
        self._param_frame = ctk.CTkFrame(top, fg_color='transparent')
        self._param_frame.pack(fill='x', padx=14, pady=(0, 10))
        self._param_vars: list[ctk.StringVar] = []
        self._on_query_change(QUERIES[0][0])

        # Result tree area
        self._result_card = ctk.CTkFrame(self, fg_color=COLORS['card_bg'], corner_radius=12)
        self._result_card.pack(fill='both', expand=True, padx=22, pady=(0, 12))

        self._status = ctk.StringVar(value='Select a query and click Run.')
        ctk.CTkLabel(self._result_card, textvariable=self._status,
                     text_color=COLORS['text_dim'],
                     font=ctk.CTkFont(size=11)).pack(anchor='w', padx=12, pady=6)
        self._tree_area = ctk.CTkFrame(self._result_card, fg_color='transparent')
        self._tree_area.pack(fill='both', expand=True)

    def _on_query_change(self, name: str):
        idx = next(i for i, q in enumerate(QUERIES) if q[0] == name)
        _, desc, _, params = QUERIES[idx]
        self._desc_lbl.configure(text=desc)

        for w in self._param_frame.winfo_children():
            w.destroy()
        self._param_vars = []

        for label, placeholder, _ in params:
            ctk.CTkLabel(self._param_frame, text=f'{label}:',
                         text_color=COLORS['text_dim']).pack(side='left', padx=(0, 4))
            v = ctk.StringVar(value=placeholder)
            ctk.CTkEntry(self._param_frame, textvariable=v,
                          width=90, height=32).pack(side='left', padx=(0, 14))
            self._param_vars.append(v)

    def _run(self):
        name = self._q_sel.get()
        idx  = next(i for i, q in enumerate(QUERIES) if q[0] == name)
        _, _, sql, param_defs = QUERIES[idx]

        params = []
        for (_, _, cast), var in zip(param_defs, self._param_vars):
            try:
                params.append(cast(var.get()))
            except ValueError:
                messagebox.showerror('Input Error', f'Invalid parameter value: {var.get()}')
                return

        try:
            rows = self._db.fetchall(sql.strip(), tuple(params))
        except Exception as e:
            messagebox.showerror('Query Error', str(e))
            return

        # Re-render result tree
        for w in self._tree_area.winfo_children():
            w.destroy()

        if not rows:
            self._status.set('Query returned 0 rows.')
            return

        self._status.set(f'{len(rows)} row(s) returned.')
        cols = tuple(rows[0].keys())
        tree = make_tree(
            self._tree_area,
            columns=cols,
            headings={c: c.replace('_', ' ').title() for c in cols},
            widths={c: 120 for c in cols}
        )
        for r in rows:
            tree.insert('', 'end', values=tuple(
                str(v) if v is not None else '—' for v in r.values()))
