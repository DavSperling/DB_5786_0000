from tkinter import messagebox
import customtkinter as ctk
from .widgets import make_tree, lbl, entry, btn, section_header
from config import COLORS

_VIEWS = {
    'Customers':             ('customer_order_summary',   False),
    'Loyalty Status':        ('customer_loyalty_status',  False),
    'Cross Activity (360°)': ('customer_cross_activity',  False),
    'Reservations':          ('reservation',              True),
    'Waitlist':              ('waitlist',                  True),
    'Loyalty Transactions':  ('loyalty_transaction',       True),
    'Feedback':              ('feedback',                  True),
}


class CustomersScreen(ctk.CTkFrame):
    def __init__(self, parent, db):
        super().__init__(parent, fg_color='transparent')
        self._db = db
        self._build()

    def refresh(self):
        self._load_view()

    # ------------------------------------------------------------------ #
    def _build(self):
        hdr = section_header(self, '👥', 'Customers & Loyalty')

        # Toolbar: view selector + search
        toolbar = ctk.CTkFrame(self, fg_color='transparent')
        toolbar.pack(fill='x', padx=22, pady=(0, 8))

        ctk.CTkLabel(toolbar, text='View:', text_color=COLORS['text_dim']).pack(side='left')
        self._view_sel = ctk.CTkOptionMenu(
            toolbar, values=list(_VIEWS.keys()), width=220,
            dynamic_resizing=False,
            command=lambda _: self._load_view()
        )
        self._view_sel.set('Customers')
        self._view_sel.pack(side='left', padx=8)

        ctk.CTkLabel(toolbar, text='Search:', text_color=COLORS['text_dim']).pack(side='left', padx=(16, 0))
        self._search_var = ctk.StringVar()
        ctk.CTkEntry(toolbar, textvariable=self._search_var,
                      placeholder_text='Name or email…', width=200, height=34).pack(side='left', padx=6)
        ctk.CTkButton(toolbar, text='🔍', width=40, height=34,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self._load_view).pack(side='left')
        ctk.CTkButton(toolbar, text='⟳', width=40, height=34,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self._clear_search).pack(side='left', padx=4)

        # Tree container
        self._tree_card = ctk.CTkFrame(self, fg_color=COLORS['card_bg'], corner_radius=12)
        self._tree_card.pack(fill='both', expand=True, padx=22, pady=(0, 12))

        self._tree = None
        self._load_view()

    def _clear_search(self):
        self._search_var.set('')
        self._load_view()

    def _load_view(self):
        view_name = self._view_sel.get()
        source, is_table = _VIEWS[view_name]
        search = self._search_var.get().strip()

        try:
            if source == 'customer_order_summary':
                rows = self._customer_order_summary(search)
            elif source == 'customer_loyalty_status':
                rows = self._customer_loyalty_status(search)
            elif source == 'customer_cross_activity':
                rows = self._customer_cross_activity(search)
            elif source == 'reservation':
                rows = self._reservations(search)
            elif source == 'waitlist':
                rows = self._waitlist(search)
            elif source == 'loyalty_transaction':
                rows = self._loyalty_transactions(search)
            elif source == 'feedback':
                rows = self._feedback(search)
            else:
                rows = []
        except Exception as e:
            messagebox.showerror('Load Error', str(e))
            return

        self._render(rows)

    def _render(self, rows: list[dict]):
        # Destroy previous tree
        for w in self._tree_card.winfo_children():
            w.destroy()
        if not rows:
            ctk.CTkLabel(self._tree_card, text='No data found.',
                         text_color=COLORS['text_dim']).pack(expand=True)
            return
        cols = tuple(rows[0].keys())
        self._tree = make_tree(
            self._tree_card,
            columns=cols,
            headings={c: c.replace('_', ' ').title() for c in cols},
            widths={c: 130 for c in cols}
        )
        for r in rows:
            self._tree.insert('', 'end', values=tuple(str(v) if v is not None else '—' for v in r.values()))

    # ---- queries ------------------------------------------------------ #
    def _customer_order_summary(self, search: str) -> list[dict]:
        q = """
            SELECT c.customer_id                                      AS id,
                   c.first_name || ' ' || c.last_name                 AS name,
                   c.email,
                   c.phone,
                   COUNT(DISTINCT o.order_id)                         AS orders,
                   COALESCE(SUM(b.total_amount),0)::NUMERIC(10,2)     AS total_spent,
                   COALESCE(AVG(b.total_amount),0)::NUMERIC(10,2)     AS avg_bill,
                   MAX(o.order_time)::TEXT                            AS last_order
            FROM customer c
            LEFT JOIN "ORDER" o ON c.customer_id = o.customer_id
            LEFT JOIN bill b    ON o.order_id    = b.order_id
        """
        params: tuple = ()
        if search:
            q += " WHERE LOWER(c.first_name||' '||c.last_name) LIKE %s OR LOWER(c.email) LIKE %s"
            params = (f'%{search.lower()}%', f'%{search.lower()}%')
        q += " GROUP BY c.customer_id,c.first_name,c.last_name,c.email,c.phone ORDER BY total_spent DESC LIMIT 200"
        return self._db.fetchall(q, params)

    def _customer_loyalty_status(self, search: str) -> list[dict]:
        q = """
            SELECT c.customer_id    AS id,
                   c.first_name||' '||c.last_name AS name,
                   COALESCE(lt.level,'No Loyalty')  AS tier,
                   COALESCE(l.points,0)             AS points,
                   COUNT(DISTINCT lx.transaction_id) AS tx_count,
                   COUNT(DISTINCT r.reservation_id)  AS reservations
            FROM customer c
            LEFT JOIN loyalty l             ON c.customer_id = l.customer_id
            LEFT JOIN loyalty_tier lt       ON l.tier_id     = lt.tier_id
            LEFT JOIN loyalty_transaction lx ON l.loyalty_id = lx.loyalty_id
            LEFT JOIN reservation r         ON c.customer_id = r.customer_id
        """
        params: tuple = ()
        if search:
            q += " WHERE LOWER(c.first_name||' '||c.last_name) LIKE %s"
            params = (f'%{search.lower()}%',)
        q += " GROUP BY c.customer_id,c.first_name,c.last_name,lt.level,l.points ORDER BY points DESC LIMIT 200"
        return self._db.fetchall(q, params)

    def _customer_cross_activity(self, search: str) -> list[dict]:
        q = """
            SELECT c.customer_id  AS id,
                   c.first_name||' '||c.last_name AS name,
                   COALESCE(lt.level,'No Loyalty') AS tier,
                   COUNT(DISTINCT r.reservation_id) AS reservations,
                   COUNT(DISTINCT o.order_id)        AS orders,
                   COALESCE(SUM(b.total_amount),0)::NUMERIC(10,2) AS revenue,
                   CASE
                       WHEN COUNT(DISTINCT o.order_id)>0 AND COUNT(DISTINCT r.reservation_id)>0 THEN 'Both'
                       WHEN COUNT(DISTINCT o.order_id)>0 THEN 'Orders only'
                       WHEN COUNT(DISTINCT r.reservation_id)>0 THEN 'Reservations only'
                       ELSE 'Inactive'
                   END AS engagement
            FROM customer c
            LEFT JOIN loyalty l       ON c.customer_id = l.customer_id
            LEFT JOIN loyalty_tier lt ON l.tier_id     = lt.tier_id
            LEFT JOIN reservation r   ON c.customer_id = r.customer_id
            LEFT JOIN "ORDER" o       ON c.customer_id = o.customer_id
            LEFT JOIN bill b          ON o.order_id    = b.order_id
        """
        params: tuple = ()
        if search:
            q += " WHERE LOWER(c.first_name||' '||c.last_name) LIKE %s"
            params = (f'%{search.lower()}%',)
        q += " GROUP BY c.customer_id,c.first_name,c.last_name,lt.level ORDER BY revenue DESC LIMIT 200"
        return self._db.fetchall(q, params)

    def _reservations(self, search: str) -> list[dict]:
        q = """
            SELECT r.reservation_id AS id,
                   c.first_name||' '||c.last_name AS customer,
                   r.datetime, r.party_size,
                   st.description AS status,
                   r.special_requests
            FROM reservation r
            JOIN customer c   ON r.customer_id = c.customer_id
            JOIN status_type st ON r.status_id = st.status_id
        """
        params: tuple = ()
        if search:
            q += " WHERE LOWER(c.first_name||' '||c.last_name) LIKE %s"
            params = (f'%{search.lower()}%',)
        q += " ORDER BY r.datetime DESC LIMIT 200"
        return self._db.fetchall(q, params)

    def _waitlist(self, search: str) -> list[dict]:
        q = """
            SELECT w.waitlist_id AS id,
                   c.first_name||' '||c.last_name AS customer,
                   w.party_size, w.request_time,
                   w.est_wait_time AS wait_min,
                   st.description AS status
            FROM waitlist w
            JOIN customer c    ON w.customer_id = c.customer_id
            JOIN status_type st ON w.status_id  = st.status_id
        """
        params: tuple = ()
        if search:
            q += " WHERE LOWER(c.first_name||' '||c.last_name) LIKE %s"
            params = (f'%{search.lower()}%',)
        q += " ORDER BY w.request_time DESC LIMIT 200"
        return self._db.fetchall(q, params)

    def _loyalty_transactions(self, search: str) -> list[dict]:
        q = """
            SELECT lx.transaction_id AS id,
                   c.first_name||' '||c.last_name AS customer,
                   lx.points_change,
                   lx.created_at,
                   r.description AS reason
            FROM loyalty_transaction lx
            JOIN loyalty l   ON lx.loyalty_id  = l.loyalty_id
            JOIN customer c  ON l.customer_id  = c.customer_id
            JOIN reason r    ON lx.reason_id   = r.reason_id
        """
        params: tuple = ()
        if search:
            q += " WHERE LOWER(c.first_name||' '||c.last_name) LIKE %s"
            params = (f'%{search.lower()}%',)
        q += " ORDER BY lx.created_at DESC LIMIT 200"
        return self._db.fetchall(q, params)

    def _feedback(self, search: str) -> list[dict]:
        q = """
            SELECT f.feedback_id AS id,
                   c.first_name||' '||c.last_name AS customer,
                   f.rating, f.feedback_date,
                   COALESCE(f.comment,'—') AS comment
            FROM feedback f
            JOIN reservation r ON f.reservation_id = r.reservation_id
            JOIN customer c    ON r.customer_id     = c.customer_id
        """
        params: tuple = ()
        if search:
            q += " WHERE LOWER(c.first_name||' '||c.last_name) LIKE %s"
            params = (f'%{search.lower()}%',)
        q += " ORDER BY f.feedback_date DESC LIMIT 200"
        return self._db.fetchall(q, params)
