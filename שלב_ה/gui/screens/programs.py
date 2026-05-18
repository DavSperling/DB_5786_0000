"""Stage 4 PL/pgSQL function & procedure runner."""
from tkinter import messagebox
import customtkinter as ctk
from .widgets import make_tree, section_header
from config import COLORS

TIERS   = ('Bronze', 'Silver', 'Gold', 'Platinum')
MONTHS  = [str(i) for i in range(1, 13)]
YEARS   = [str(y) for y in range(2020, 2027)]


class ProgramsScreen(ctk.CTkFrame):
    def __init__(self, parent, db):
        super().__init__(parent, fg_color='transparent')
        self._db = db
        self._build()

    def refresh(self):
        pass

    # ------------------------------------------------------------------ #
    def _build(self):
        section_header(self, '⚙️', 'Stage 4 – Functions & Procedures')

        scroll = ctk.CTkScrollableFrame(self, fg_color='transparent')
        scroll.pack(fill='both', expand=True, padx=22, pady=(0, 12))

        self._build_f1(scroll)
        self._build_f2(scroll)
        self._build_p1(scroll)
        self._build_p2(scroll)
        self._build_waiter_report(scroll)

    # ------------------------------------------------------------------ #
    def _card(self, parent, title: str, subtitle: str) -> ctk.CTkFrame:
        card = ctk.CTkFrame(parent, fg_color=COLORS['card_bg'], corner_radius=12)
        card.pack(fill='x', pady=(0, 10))
        ctk.CTkLabel(card, text=title,
                     font=ctk.CTkFont(size=14, weight='bold'),
                     text_color=COLORS['secondary']).pack(anchor='w', padx=16, pady=(12, 2))
        ctk.CTkLabel(card, text=subtitle,
                     font=ctk.CTkFont(size=11),
                     text_color=COLORS['text_dim']).pack(anchor='w', padx=16, pady=(0, 8))
        return card

    def _output_box(self, parent) -> ctk.CTkTextbox:
        box = ctk.CTkTextbox(parent, height=130, corner_radius=8,
                              fg_color=COLORS['content_bg'],
                              text_color=COLORS['text_main'],
                              font=ctk.CTkFont(family='Consolas', size=11))
        box.pack(fill='x', padx=16, pady=(0, 14))
        box.configure(state='disabled')
        return box

    def _write(self, box: ctk.CTkTextbox, text: str):
        box.configure(state='normal')
        box.delete('1.0', 'end')
        box.insert('end', text)
        box.configure(state='disabled')

    # ------------------------------------------------------------------ #
    #  F1 – get_top_loyalty_customers (REFCURSOR)
    # ------------------------------------------------------------------ #
    def _build_f1(self, parent):
        card = self._card(parent,
                          'F1 – get_top_loyalty_customers',
                          'Returns top customers of a loyalty tier via a REF CURSOR.')
        row = ctk.CTkFrame(card, fg_color='transparent')
        row.pack(fill='x', padx=16, pady=(0, 8))

        ctk.CTkLabel(row, text='Tier:', text_color=COLORS['text_dim']).pack(side='left')
        self._f1_tier = ctk.CTkOptionMenu(row, values=list(TIERS), width=120)
        self._f1_tier.set('Gold')
        self._f1_tier.pack(side='left', padx=8)

        ctk.CTkLabel(row, text='Min Orders:', text_color=COLORS['text_dim']).pack(side='left')
        self._f1_min = ctk.StringVar(value='0')
        ctk.CTkEntry(row, textvariable=self._f1_min, width=70, height=34).pack(side='left', padx=8)

        ctk.CTkButton(row, text='▶  Run', height=34,
                       fg_color=COLORS['primary'], hover_color=COLORS['primary_hov'],
                       command=self._run_f1).pack(side='right')

        self._f1_tree_area = ctk.CTkFrame(card, fg_color='transparent')
        self._f1_tree_area.pack(fill='x', padx=16, pady=(0, 12))
        self._f1_status = ctk.CTkLabel(self._f1_tree_area, text='',
                                        text_color=COLORS['text_dim'],
                                        font=ctk.CTkFont(size=11))
        self._f1_status.pack(anchor='w')

    def _run_f1(self):
        try:
            min_ord = int(self._f1_min.get())
        except ValueError:
            messagebox.showerror('Input Error', 'Min Orders must be an integer.')
            return
        try:
            rows = self._db.call_refcursor_function(
                'get_top_loyalty_customers',
                (self._f1_tier.get(), min_ord)
            )
        except Exception as e:
            messagebox.showerror('Function Error', str(e))
            return

        for w in self._f1_tree_area.winfo_children():
            w.destroy()

        if not rows:
            ctk.CTkLabel(self._f1_tree_area, text='No customers found.',
                         text_color=COLORS['text_dim']).pack(anchor='w')
            return

        self._f1_status = ctk.CTkLabel(self._f1_tree_area,
                                        text=f'{len(rows)} customer(s) returned.',
                                        text_color=COLORS['success'],
                                        font=ctk.CTkFont(size=11))
        self._f1_status.pack(anchor='w', pady=(0, 4))

        cols = tuple(rows[0].keys())
        tree = make_tree(
            self._f1_tree_area,
            columns=cols,
            headings={c: c.replace('_', ' ').title() for c in cols},
            widths={'customer_name': 180, 'reward_category': 120}
        )
        for r in rows:
            tree.insert('', 'end', values=tuple(
                str(v) if v is not None else '—' for v in r.values()))

    # ------------------------------------------------------------------ #
    #  F2 – calculate_period_revenue (scalar)
    # ------------------------------------------------------------------ #
    def _build_f2(self, parent):
        card = self._card(parent,
                          'F2 – calculate_period_revenue',
                          'Returns the net revenue between two dates (skips cancelled orders).')
        row = ctk.CTkFrame(card, fg_color='transparent')
        row.pack(fill='x', padx=16, pady=(0, 8))

        ctk.CTkLabel(row, text='Start (YYYY-MM-DD):',
                     text_color=COLORS['text_dim']).pack(side='left')
        self._f2_start = ctk.StringVar(value='2024-01-01')
        ctk.CTkEntry(row, textvariable=self._f2_start, width=110, height=34).pack(side='left', padx=6)

        ctk.CTkLabel(row, text='End:', text_color=COLORS['text_dim']).pack(side='left')
        self._f2_end = ctk.StringVar(value='2024-12-31')
        ctk.CTkEntry(row, textvariable=self._f2_end, width=110, height=34).pack(side='left', padx=6)

        ctk.CTkButton(row, text='▶  Run', height=34,
                       fg_color=COLORS['primary'], hover_color=COLORS['primary_hov'],
                       command=self._run_f2).pack(side='right')

        self._f2_out = self._output_box(card)

    def _run_f2(self):
        try:
            result = self._db.call_scalar_function(
                'calculate_period_revenue',
                (self._f2_start.get(), self._f2_end.get())
            )
            self._write(self._f2_out,
                        f'Period: {self._f2_start.get()}  →  {self._f2_end.get()}\n'
                        f'Net Revenue: €{float(result):,.2f}')
        except Exception as e:
            self._write(self._f2_out, f'ERROR:\n{e}')

    # ------------------------------------------------------------------ #
    #  P1 – apply_loyalty_tier_discount
    # ------------------------------------------------------------------ #
    def _build_p1(self, parent):
        card = self._card(parent,
                          'P1 – apply_loyalty_tier_discount',
                          'Applies an extra discount (capped per tier) to in-progress bills '
                          'of a loyalty tier, and credits loyalty points.')
        row = ctk.CTkFrame(card, fg_color='transparent')
        row.pack(fill='x', padx=16, pady=(0, 8))

        ctk.CTkLabel(row, text='Tier:', text_color=COLORS['text_dim']).pack(side='left')
        self._p1_tier = ctk.CTkOptionMenu(row, values=list(TIERS), width=120)
        self._p1_tier.set('Gold')
        self._p1_tier.pack(side='left', padx=8)

        ctk.CTkLabel(row, text='Extra %:', text_color=COLORS['text_dim']).pack(side='left')
        self._p1_pct = ctk.StringVar(value='5')
        ctk.CTkEntry(row, textvariable=self._p1_pct, width=70, height=34).pack(side='left', padx=8)

        ctk.CTkButton(row, text='▶  Run', height=34,
                       fg_color=COLORS['warning'], hover_color='#B7770D',
                       command=self._run_p1).pack(side='right')

        self._p1_out = self._output_box(card)

    def _run_p1(self):
        try:
            pct = float(self._p1_pct.get())
        except ValueError:
            messagebox.showerror('Input Error', 'Extra % must be numeric.')
            return
        if not messagebox.askyesno('Confirm', f'Apply {pct}% extra discount to all '
                                               f'"{self._p1_tier.get()}" in-progress bills?'):
            return
        try:
            msg = self._db.call_procedure(
                'apply_loyalty_tier_discount',
                (self._p1_tier.get(), pct)
            )
            self._write(self._p1_out, msg)
        except Exception as e:
            self._write(self._p1_out, f'ERROR:\n{e}')

    # ------------------------------------------------------------------ #
    #  P2 – generate_monthly_waiter_report
    # ------------------------------------------------------------------ #
    def _build_p2(self, parent):
        card = self._card(parent,
                          'P2 – generate_monthly_waiter_report',
                          'Computes and persists monthly per-waiter KPIs into MONTHLY_WAITER_REPORT.')
        row = ctk.CTkFrame(card, fg_color='transparent')
        row.pack(fill='x', padx=16, pady=(0, 8))

        ctk.CTkLabel(row, text='Year:', text_color=COLORS['text_dim']).pack(side='left')
        self._p2_year = ctk.CTkOptionMenu(row, values=YEARS, width=90)
        self._p2_year.set('2024')
        self._p2_year.pack(side='left', padx=8)

        ctk.CTkLabel(row, text='Month:', text_color=COLORS['text_dim']).pack(side='left')
        self._p2_month = ctk.CTkOptionMenu(row, values=MONTHS, width=70)
        self._p2_month.set('4')
        self._p2_month.pack(side='left', padx=8)

        ctk.CTkButton(row, text='▶  Run', height=34,
                       fg_color=COLORS['warning'], hover_color='#B7770D',
                       command=self._run_p2).pack(side='right')

        self._p2_out = self._output_box(card)

    def _run_p2(self):
        try:
            yr  = int(self._p2_year.get())
            mo  = int(self._p2_month.get())
        except ValueError:
            messagebox.showerror('Input Error', 'Year and month must be integers.')
            return
        try:
            msg = self._db.call_procedure('generate_monthly_waiter_report', (yr, mo))
            self._write(self._p2_out, msg or f'Report generated for {yr}-{mo:02d}.')
        except Exception as e:
            self._write(self._p2_out, f'ERROR:\n{e}')

    # ------------------------------------------------------------------ #
    #  View MONTHLY_WAITER_REPORT
    # ------------------------------------------------------------------ #
    def _build_waiter_report(self, parent):
        card = self._card(parent,
                          'View Monthly Waiter Report',
                          'Browse the MONTHLY_WAITER_REPORT table after running P2.')
        row = ctk.CTkFrame(card, fg_color='transparent')
        row.pack(fill='x', padx=16, pady=(0, 8))

        ctk.CTkLabel(row, text='Year:', text_color=COLORS['text_dim']).pack(side='left')
        self._vr_year = ctk.CTkOptionMenu(row, values=YEARS, width=90)
        self._vr_year.set('2024')
        self._vr_year.pack(side='left', padx=8)

        ctk.CTkLabel(row, text='Month:', text_color=COLORS['text_dim']).pack(side='left')
        self._vr_month = ctk.CTkOptionMenu(row, values=['All'] + MONTHS, width=70)
        self._vr_month.set('4')
        self._vr_month.pack(side='left', padx=8)

        ctk.CTkButton(row, text='📊  Load Report', height=34,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self._load_report).pack(side='right')

        self._vr_area = ctk.CTkFrame(card, fg_color='transparent')
        self._vr_area.pack(fill='x', padx=16, pady=(0, 12))

    def _load_report(self):
        for w in self._vr_area.winfo_children():
            w.destroy()
        try:
            yr = int(self._vr_year.get())
            mo = self._vr_month.get()
            if mo == 'All':
                rows = self._db.fetchall(
                    'SELECT waiter_id, report_year AS year, report_month AS month,'
                    ' nb_orders, total_revenue, avg_bill, perf_level'
                    ' FROM monthly_waiter_report WHERE report_year=%s'
                    ' ORDER BY total_revenue DESC', (yr,))
            else:
                rows = self._db.fetchall(
                    'SELECT waiter_id, report_year AS year, report_month AS month,'
                    ' nb_orders, total_revenue, avg_bill, perf_level'
                    ' FROM monthly_waiter_report WHERE report_year=%s AND report_month=%s'
                    ' ORDER BY total_revenue DESC', (yr, int(mo)))
        except Exception as e:
            ctk.CTkLabel(self._vr_area, text=f'Error: {e}',
                         text_color=COLORS['danger']).pack(anchor='w')
            return

        if not rows:
            ctk.CTkLabel(self._vr_area, text='No report data. Run P2 first.',
                         text_color=COLORS['text_dim']).pack(anchor='w')
            return

        cols = tuple(rows[0].keys())
        pal  = {'HIGH': COLORS['success'], 'MEDIUM': COLORS['secondary'], 'LOW': COLORS['danger']}
        tree = make_tree(
            self._vr_area,
            columns=cols,
            headings={c: c.replace('_', ' ').title() for c in cols},
            widths={'total_revenue': 120, 'avg_bill': 100}
        )
        for r in rows:
            tag = r.get('perf_level', '')
            tree.insert('', 'end', values=tuple(
                str(v) if v is not None else '—' for v in r.values()), tags=(tag,))
        for lvl, col in pal.items():
            tree.tag_configure(lvl, foreground=col)
