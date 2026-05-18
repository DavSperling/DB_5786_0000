import customtkinter as ctk
from config import COLORS


class DashboardScreen(ctk.CTkFrame):
    def __init__(self, parent, db):
        super().__init__(parent, fg_color='transparent')
        self._db = db
        self._build()

    def refresh(self):
        pass  # stats are built once; call _build() to re-render if needed

    def _build(self):
        # Header
        hdr = ctk.CTkFrame(self, fg_color='transparent')
        hdr.pack(fill='x', padx=28, pady=(22, 10))
        ctk.CTkLabel(hdr, text='🏠  Dashboard',
                     font=ctk.CTkFont(size=24, weight='bold'),
                     text_color=COLORS['text_main']).pack(anchor='w')
        ctk.CTkLabel(hdr, text='Restaurant overview',
                     text_color=COLORS['text_dim']).pack(anchor='w')

        stats = self._stats()

        # ---- Top stat cards ----
        row1 = ctk.CTkFrame(self, fg_color='transparent')
        row1.pack(fill='x', padx=28, pady=(0, 10))

        card_data = [
            ('📋', 'Orders',     stats['orders'],    COLORS['primary']),
            ('🧾', 'Bills',      stats['bills'],     COLORS['secondary']),
            ('💳', 'Payments',   stats['payments'],  '#2980B9'),
            ('🏷️', 'Discounts',  stats['discounts'], '#8E44AD'),
            ('👥', 'Customers',  stats['customers'], COLORS['success']),
        ]
        for icon, label, val, color in card_data:
            c = ctk.CTkFrame(row1, fg_color=COLORS['card_bg'], corner_radius=12)
            c.pack(side='left', fill='both', expand=True, padx=5)
            ctk.CTkLabel(c, text=icon, font=ctk.CTkFont(size=24)).pack(pady=(16, 2))
            ctk.CTkLabel(c, text=label, font=ctk.CTkFont(size=11),
                         text_color=COLORS['text_dim']).pack()
            ctk.CTkLabel(c, text=str(val),
                         font=ctk.CTkFont(size=26, weight='bold'),
                         text_color=color).pack(pady=(2, 16))

        # ---- Order status breakdown ----
        sc = ctk.CTkFrame(self, fg_color=COLORS['card_bg'], corner_radius=12)
        sc.pack(fill='x', padx=28, pady=(0, 10))
        ctk.CTkLabel(sc, text='Order Status Breakdown',
                     font=ctk.CTkFont(size=13, weight='bold'),
                     text_color=COLORS['text_main']).pack(anchor='w', padx=18, pady=(14, 8))

        statuses = self._order_statuses()
        srow = ctk.CTkFrame(sc, fg_color='transparent')
        srow.pack(fill='x', padx=18, pady=(0, 14))
        palette = {'Completed': COLORS['success'], 'In Progress': COLORS['secondary'],
                   'Pending': '#2980B9', 'Cancelled': COLORS['danger']}
        for r in statuses:
            st = r.get('order_status', '')
            cnt = r.get('count', 0)
            cell = ctk.CTkFrame(srow, fg_color=COLORS['content_bg'], corner_radius=8)
            cell.pack(side='left', fill='both', expand=True, padx=4)
            ctk.CTkLabel(cell, text=st, font=ctk.CTkFont(size=11),
                         text_color=COLORS['text_dim']).pack(pady=(10, 2))
            ctk.CTkLabel(cell, text=str(cnt),
                         font=ctk.CTkFont(size=22, weight='bold'),
                         text_color=palette.get(st, COLORS['text_main'])).pack(pady=(0, 10))

        # ---- Revenue summary ----
        rev = self._revenue()
        rc = ctk.CTkFrame(self, fg_color=COLORS['card_bg'], corner_radius=12)
        rc.pack(fill='x', padx=28, pady=(0, 10))
        ctk.CTkLabel(rc, text='Revenue Summary',
                     font=ctk.CTkFont(size=13, weight='bold'),
                     text_color=COLORS['text_main']).pack(anchor='w', padx=18, pady=(14, 8))
        rrow = ctk.CTkFrame(rc, fg_color='transparent')
        rrow.pack(fill='x', padx=18, pady=(0, 14))
        for label, val in [('Total Revenue', f"€{rev['total']:,.2f}"),
                            ('Total Tax',     f"€{rev['tax']:,.2f}"),
                            ('Average Bill',  f"€{rev['avg']:,.2f}")]:
            cell = ctk.CTkFrame(rrow, fg_color=COLORS['content_bg'], corner_radius=8)
            cell.pack(side='left', fill='both', expand=True, padx=4)
            ctk.CTkLabel(cell, text=label, font=ctk.CTkFont(size=11),
                         text_color=COLORS['text_dim']).pack(pady=(10, 2))
            ctk.CTkLabel(cell, text=val,
                         font=ctk.CTkFont(size=18, weight='bold'),
                         text_color=COLORS['secondary']).pack(pady=(0, 10))

    # ---- DB queries --------------------------------------------------- #
    def _stats(self) -> dict:
        try:
            q = lambda sql: self._db.fetchone(sql)['c']
            return {
                'orders':    q('SELECT COUNT(*) AS c FROM "ORDER"'),
                'bills':     q('SELECT COUNT(*) AS c FROM bill'),
                'payments':  q('SELECT COUNT(*) AS c FROM payment'),
                'discounts': q('SELECT COUNT(*) AS c FROM discount'),
                'customers': q('SELECT COUNT(*) AS c FROM customer'),
            }
        except Exception:
            return {k: '?' for k in ('orders', 'bills', 'payments', 'discounts', 'customers')}

    def _order_statuses(self) -> list:
        try:
            return self._db.fetchall(
                "SELECT order_status, COUNT(*) AS count FROM \"ORDER\" "
                "GROUP BY order_status ORDER BY count DESC"
            )
        except Exception:
            return []

    def _revenue(self) -> dict:
        try:
            r = self._db.fetchone(
                "SELECT COALESCE(SUM(total_amount),0) AS total, "
                "COALESCE(SUM(tax),0) AS tax, "
                "COALESCE(AVG(total_amount),0) AS avg FROM bill"
            )
            return {k: float(r[k]) for k in ('total', 'tax', 'avg')}
        except Exception:
            return {'total': 0.0, 'tax': 0.0, 'avg': 0.0}
