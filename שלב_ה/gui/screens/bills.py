from tkinter import messagebox
import customtkinter as ctk
from .widgets import make_tree, lbl, entry, btn, section_header, split_layout, tabview
from config import COLORS


class BillsScreen(ctk.CTkFrame):
    def __init__(self, parent, db):
        super().__init__(parent, fg_color='transparent')
        self._db = db
        # Detect whether BILL has 'discount' or 'discount_amount'
        cols = self._db.table_columns('bill')
        self._disc_col = 'discount_amount' if 'discount_amount' in cols else 'discount'
        self._has_final = 'final_amount' in cols
        self._build()
        self.refresh()

    def refresh(self):
        self._tree.delete(*self._tree.get_children())
        try:
            final_expr = 'b.final_amount' if self._has_final else \
                         f'(b.total_amount - COALESCE(b.{self._disc_col},0) + b.tax)'
            rows = self._db.fetchall(f"""
                SELECT b.bill_id,
                       b.order_id,
                       COALESCE(c.first_name||' '||c.last_name,'Unknown') AS customer,
                       b.total_amount,
                       b.tax,
                       COALESCE(b.{self._disc_col},0) AS discount,
                       {final_expr} AS final_amount,
                       TO_CHAR(b.bill_time,'YYYY-MM-DD HH24:MI') AS bill_time
                FROM bill b
                JOIN "ORDER" o ON b.order_id = o.order_id
                LEFT JOIN customer c ON o.customer_id = c.customer_id
                ORDER BY b.bill_id DESC LIMIT 500
            """)
            for r in rows:
                self._tree.insert('', 'end', iid=str(r['bill_id']),
                                  values=(r['bill_id'], r['order_id'], r['customer'],
                                          f"€{float(r['total_amount']):.2f}",
                                          f"€{float(r['tax']):.2f}",
                                          f"€{float(r['discount']):.2f}",
                                          f"€{float(r['final_amount']):.2f}",
                                          r['bill_time']))
        except Exception as e:
            messagebox.showerror('Load Error', str(e))

    def _build(self):
        hdr = section_header(self, '🧾', 'Bills')
        ctk.CTkButton(hdr, text='⟳ Refresh', width=90, height=32,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self.refresh).pack(side='right')

        left, right = split_layout(self)
        self._tree = make_tree(
            left,
            columns=('bill_id', 'order_id', 'customer', 'total', 'tax', 'discount', 'final', 'bill_time'),
            headings={'bill_id': 'ID', 'order_id': 'Order', 'customer': 'Customer',
                      'total': 'Total', 'tax': 'Tax', 'discount': 'Discount',
                      'final': 'Final', 'bill_time': 'Bill Time'},
            widths={'customer': 150, 'bill_time': 135}
        )
        self._tree.bind('<<TreeviewSelect>>', self._on_select)

        tv = tabview(right)
        self._build_insert(tv.tab('Insert'))
        self._build_update(tv.tab('Update'))
        self._build_delete(tv.tab('Delete'))

    def _on_select(self, _):
        sel = self._tree.selection()
        if sel:
            self._del_id.set(str(self._tree.item(sel[0])['values'][0]))

    # ---- INSERT ------------------------------------------------------- #
    def _build_insert(self, p):
        lbl(p, 'Order ID *  (must not have a bill)')
        self._ins_oid = ctk.StringVar()
        entry(p, self._ins_oid, 'e.g. 200')

        lbl(p, 'Total Amount *')
        self._ins_total = ctk.StringVar()
        entry(p, self._ins_total, 'e.g. 45.00')

        lbl(p, 'Tax *')
        self._ins_tax = ctk.StringVar(value='0.00')
        entry(p, self._ins_tax, '0.00')

        lbl(p, 'Discount')
        self._ins_disc = ctk.StringVar(value='0.00')
        entry(p, self._ins_disc, '0.00')

        btn(p, '➕  Insert Bill', COLORS['success'], self._do_insert,
            hover=COLORS['success_hov'])

    def _do_insert(self):
        try:
            oid   = int(self._ins_oid.get())
            total = float(self._ins_total.get())
            tax   = float(self._ins_tax.get())
            disc  = float(self._ins_disc.get())
        except ValueError:
            messagebox.showerror('Input Error', 'All numeric fields required.')
            return
        try:
            nid = self._db.next_id('bill', 'bill_id')
            self._db.execute(
                f'INSERT INTO bill(bill_id,order_id,total_amount,tax,{self._disc_col})'
                f' VALUES (%s,%s,%s,%s,%s)',
                (nid, oid, total, tax, disc)
            )
            messagebox.showinfo('Success', f'Bill #{nid} inserted.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- UPDATE ------------------------------------------------------- #
    def _build_update(self, p):
        lbl(p, 'Bill ID  (load then edit)')
        frm = ctk.CTkFrame(p, fg_color='transparent')
        frm.pack(fill='x', padx=14)
        self._upd_id = ctk.StringVar()
        ctk.CTkEntry(frm, textvariable=self._upd_id,
                      placeholder_text='Bill ID', height=36).pack(side='left', fill='x', expand=True)
        ctk.CTkButton(frm, text='Load', width=56, height=36,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self._load_upd).pack(side='left', padx=(4, 0))

        lbl(p, 'Total Amount')
        self._upd_total = ctk.StringVar()
        entry(p, self._upd_total)

        lbl(p, 'Tax')
        self._upd_tax = ctk.StringVar()
        entry(p, self._upd_tax)

        lbl(p, 'Discount')
        self._upd_disc = ctk.StringVar()
        entry(p, self._upd_disc)

        btn(p, '✏️  Update Bill', COLORS['warning'], self._do_update)

    def _load_upd(self):
        bid_s = self._upd_id.get().strip()
        if not bid_s.isdigit():
            messagebox.showerror('Input Error', 'Enter a numeric Bill ID.')
            return
        row = self._db.fetchone(
            f'SELECT bill_id,total_amount,tax,{self._disc_col} AS disc'
            f' FROM bill WHERE bill_id=%s', (int(bid_s),))
        if not row:
            messagebox.showwarning('Not Found', f'No bill #{bid_s}.')
            return
        self._upd_total.set(str(row['total_amount']))
        self._upd_tax.set(str(row['tax']))
        self._upd_disc.set(str(row['disc'] or 0))

    def _do_update(self):
        bid_s = self._upd_id.get().strip()
        if not bid_s.isdigit():
            messagebox.showerror('Input Error', 'Load a bill first.')
            return
        try:
            total = float(self._upd_total.get())
            tax   = float(self._upd_tax.get())
            disc  = float(self._upd_disc.get())
        except ValueError:
            messagebox.showerror('Input Error', 'All fields must be numeric.')
            return
        try:
            rc = self._db.execute(
                f'UPDATE bill SET total_amount=%s,tax=%s,{self._disc_col}=%s'
                f' WHERE bill_id=%s',
                (total, tax, disc, int(bid_s))
            )
            messagebox.showinfo('Success', 'Bill updated.' if rc else 'No changes.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- DELETE ------------------------------------------------------- #
    def _build_delete(self, p):
        lbl(p, 'Bill ID  (click row or enter)')
        self._del_id = ctk.StringVar()
        entry(p, self._del_id, 'Bill ID')
        ctk.CTkLabel(p, text='⚠️  Also removes linked payments.',
                     text_color=COLORS['warning'],
                     font=ctk.CTkFont(size=11)).pack(padx=14, pady=6)
        btn(p, '🗑️  Delete Bill', COLORS['danger'], self._do_delete,
            hover=COLORS['primary_hov'])

    def _do_delete(self):
        bid_s = self._del_id.get().strip()
        if not bid_s.isdigit():
            messagebox.showerror('Input Error', 'Enter or select a Bill ID.')
            return
        if not messagebox.askyesno('Confirm', f'Delete bill #{bid_s} and its payments?'):
            return
        try:
            self._db.execute('DELETE FROM payment WHERE bill_id=%s', (int(bid_s),))
            self._db.execute('DELETE FROM bill_discount WHERE bill_id=%s', (int(bid_s),))
            rc = self._db.execute('DELETE FROM bill WHERE bill_id=%s', (int(bid_s),))
            messagebox.showinfo('Deleted', 'Bill deleted.' if rc else 'Not found.')
            self._del_id.set('')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))
