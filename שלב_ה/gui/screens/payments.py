from tkinter import messagebox
import customtkinter as ctk
from .widgets import make_tree, lbl, entry, btn, section_header, split_layout, tabview
from config import COLORS

METHODS = ('Cash', 'Credit Card', 'Debit Card', 'Mobile Payment')


class PaymentsScreen(ctk.CTkFrame):
    def __init__(self, parent, db):
        super().__init__(parent, fg_color='transparent')
        self._db = db
        self._build()
        self.refresh()

    def refresh(self):
        self._tree.delete(*self._tree.get_children())
        try:
            rows = self._db.fetchall("""
                SELECT p.payment_id,
                       p.bill_id,
                       COALESCE(c.first_name||' '||c.last_name,'Unknown') AS customer,
                       p.payment_method,
                       TO_CHAR(p.payment_time,'YYYY-MM-DD HH24:MI') AS pay_time,
                       p.amount
                FROM payment p
                JOIN bill b ON p.bill_id = b.bill_id
                JOIN "ORDER" o ON b.order_id = o.order_id
                LEFT JOIN customer c ON o.customer_id = c.customer_id
                ORDER BY p.payment_id DESC LIMIT 500
            """)
            for r in rows:
                self._tree.insert('', 'end', iid=str(r['payment_id']),
                                  values=(r['payment_id'], r['bill_id'], r['customer'],
                                          r['payment_method'],
                                          r['pay_time'],
                                          f"€{float(r['amount']):.2f}"))
        except Exception as e:
            messagebox.showerror('Load Error', str(e))

    def _build(self):
        hdr = section_header(self, '💳', 'Payments')
        ctk.CTkButton(hdr, text='⟳ Refresh', width=90, height=32,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self.refresh).pack(side='right')

        left, right = split_layout(self)
        self._tree = make_tree(
            left,
            columns=('pay_id', 'bill_id', 'customer', 'method', 'pay_time', 'amount'),
            headings={'pay_id': 'ID', 'bill_id': 'Bill', 'customer': 'Customer',
                      'method': 'Method', 'pay_time': 'Payment Time', 'amount': 'Amount'},
            widths={'customer': 150, 'method': 110, 'pay_time': 135}
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
        lbl(p, 'Bill ID *')
        self._ins_bid = ctk.StringVar()
        entry(p, self._ins_bid, 'e.g. 100')

        lbl(p, 'Amount *')
        self._ins_amt = ctk.StringVar()
        entry(p, self._ins_amt, 'e.g. 25.50')

        lbl(p, 'Payment Method *')
        self._ins_method = ctk.CTkOptionMenu(p, values=list(METHODS), dynamic_resizing=False)
        self._ins_method.set('Cash')
        self._ins_method.pack(fill='x', padx=14)

        btn(p, '➕  Insert Payment', COLORS['success'], self._do_insert,
            hover=COLORS['success_hov'])

    def _do_insert(self):
        try:
            bid = int(self._ins_bid.get())
            amt = float(self._ins_amt.get())
            if amt <= 0:
                raise ValueError('Amount must be > 0')
        except ValueError as e:
            messagebox.showerror('Input Error', str(e))
            return
        try:
            nid = self._db.next_id('payment', 'payment_id')
            self._db.execute(
                'INSERT INTO payment(payment_id,bill_id,payment_method,amount)'
                ' VALUES (%s,%s,%s,%s)',
                (nid, bid, self._ins_method.get(), amt)
            )
            messagebox.showinfo('Success', f'Payment #{nid} inserted.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- UPDATE ------------------------------------------------------- #
    def _build_update(self, p):
        lbl(p, 'Payment ID  (load then edit)')
        frm = ctk.CTkFrame(p, fg_color='transparent')
        frm.pack(fill='x', padx=14)
        self._upd_id = ctk.StringVar()
        ctk.CTkEntry(frm, textvariable=self._upd_id,
                      placeholder_text='Payment ID', height=36).pack(side='left', fill='x', expand=True)
        ctk.CTkButton(frm, text='Load', width=56, height=36,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self._load_upd).pack(side='left', padx=(4, 0))

        lbl(p, 'Amount')
        self._upd_amt = ctk.StringVar()
        entry(p, self._upd_amt)

        lbl(p, 'Payment Method')
        self._upd_method = ctk.CTkOptionMenu(p, values=list(METHODS), dynamic_resizing=False)
        self._upd_method.pack(fill='x', padx=14)

        btn(p, '✏️  Update Payment', COLORS['warning'], self._do_update)

    def _load_upd(self):
        pid_s = self._upd_id.get().strip()
        if not pid_s.isdigit():
            messagebox.showerror('Input Error', 'Enter a numeric Payment ID.')
            return
        row = self._db.fetchone(
            'SELECT payment_id,payment_method,amount FROM payment WHERE payment_id=%s',
            (int(pid_s),))
        if not row:
            messagebox.showwarning('Not Found', f'No payment #{pid_s}.')
            return
        self._upd_amt.set(str(row['amount']))
        self._upd_method.set(row['payment_method'])

    def _do_update(self):
        pid_s = self._upd_id.get().strip()
        if not pid_s.isdigit():
            messagebox.showerror('Input Error', 'Load a payment first.')
            return
        try:
            amt = float(self._upd_amt.get())
        except ValueError:
            messagebox.showerror('Input Error', 'Amount must be numeric.')
            return
        try:
            rc = self._db.execute(
                'UPDATE payment SET amount=%s,payment_method=%s WHERE payment_id=%s',
                (amt, self._upd_method.get(), int(pid_s))
            )
            messagebox.showinfo('Success', 'Payment updated.' if rc else 'No changes.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- DELETE ------------------------------------------------------- #
    def _build_delete(self, p):
        lbl(p, 'Payment ID  (click row or enter)')
        self._del_id = ctk.StringVar()
        entry(p, self._del_id, 'Payment ID')
        btn(p, '🗑️  Delete Payment', COLORS['danger'], self._do_delete,
            hover=COLORS['primary_hov'])

    def _do_delete(self):
        pid_s = self._del_id.get().strip()
        if not pid_s.isdigit():
            messagebox.showerror('Input Error', 'Enter or select a Payment ID.')
            return
        if not messagebox.askyesno('Confirm', f'Delete payment #{pid_s}?'):
            return
        try:
            rc = self._db.execute('DELETE FROM payment WHERE payment_id=%s', (int(pid_s),))
            messagebox.showinfo('Deleted', 'Payment deleted.' if rc else 'Not found.')
            self._del_id.set('')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))
