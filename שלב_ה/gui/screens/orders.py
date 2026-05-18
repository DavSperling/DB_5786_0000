from tkinter import messagebox
import customtkinter as ctk
from .widgets import make_tree, lbl, entry, btn, section_header, split_layout, tabview
from config import COLORS

STATUSES = ('Pending', 'In Progress', 'Completed', 'Cancelled')


class OrdersScreen(ctk.CTkFrame):
    def __init__(self, parent, db):
        super().__init__(parent, fg_color='transparent')
        self._db = db
        self._build()
        self.refresh()

    def refresh(self):
        self._tree.delete(*self._tree.get_children())
        try:
            rows = self._db.fetchall("""
                SELECT o.order_id,
                       COALESCE(c.first_name || ' ' || c.last_name, 'Unknown') AS customer,
                       'Waiter #' || o.waiter_id  AS waiter,
                       'Table #'  || o.table_id   AS tbl,
                       TO_CHAR(o.order_time, 'YYYY-MM-DD HH24:MI') AS otime,
                       o.order_status AS status
                FROM "ORDER" o
                LEFT JOIN customer c ON o.customer_id = c.customer_id
                ORDER BY o.order_id DESC LIMIT 500
            """)
            pal = {'Completed': COLORS['success'], 'In Progress': COLORS['secondary'],
                   'Pending': '#2980B9', 'Cancelled': COLORS['danger']}
            for r in rows:
                tag = r['status'].lower().replace(' ', '_')
                self._tree.insert('', 'end', iid=str(r['order_id']),
                                  values=(r['order_id'], r['customer'], r['waiter'],
                                          r['tbl'], r['otime'], r['status']),
                                  tags=(tag,))
            for k, col in pal.items():
                self._tree.tag_configure(k.lower().replace(' ', '_'), foreground=col)
        except Exception as e:
            messagebox.showerror('Load Error', str(e))

    def _build(self):
        hdr = section_header(self, '📋', 'Orders')
        ctk.CTkButton(hdr, text='⟳ Refresh', width=90, height=32,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self.refresh).pack(side='right')

        left, right = split_layout(self)

        self._tree = make_tree(
            left,
            columns=('order_id', 'customer', 'waiter', 'tbl', 'otime', 'status'),
            headings={'order_id': 'ID', 'customer': 'Customer', 'waiter': 'Waiter',
                      'tbl': 'Table', 'otime': 'Order Time', 'status': 'Status'},
            widths={'customer': 160, 'otime': 140, 'status': 100}
        )
        self._tree.bind('<<TreeviewSelect>>', self._on_select)

        tv = tabview(right)
        self._build_insert(tv.tab('Insert'))
        self._build_update(tv.tab('Update'))
        self._build_delete(tv.tab('Delete'))

    # ------------------------------------------------------------------ #
    def _on_select(self, _):
        sel = self._tree.selection()
        if sel:
            oid = self._tree.item(sel[0])['values'][0]
            self._del_id.set(str(oid))

    # ---- INSERT ------------------------------------------------------- #
    def _build_insert(self, p):
        lbl(p, 'Customer ID  (optional)')
        self._ins_cid = ctk.StringVar()
        entry(p, self._ins_cid, 'e.g. 42')

        lbl(p, 'Waiter ID *')
        self._ins_wid = ctk.StringVar()
        entry(p, self._ins_wid, 'e.g. 3')

        lbl(p, 'Table ID *')
        self._ins_tid = ctk.StringVar()
        entry(p, self._ins_tid, 'e.g. 7')

        lbl(p, 'Status *')
        self._ins_status = ctk.CTkOptionMenu(p, values=list(STATUSES), dynamic_resizing=False)
        self._ins_status.set('Pending')
        self._ins_status.pack(fill='x', padx=14)

        btn(p, '➕  Insert Order', COLORS['success'], self._do_insert,
            hover=COLORS['success_hov'])

    def _do_insert(self):
        try:
            cid = int(self._ins_cid.get()) if self._ins_cid.get().strip() else None
            wid = int(self._ins_wid.get())
            tid = int(self._ins_tid.get())
        except ValueError:
            messagebox.showerror('Input Error', 'Waiter ID and Table ID must be integers.')
            return
        try:
            nid = self._db.next_id('"ORDER"', 'order_id')
            self._db.execute(
                'INSERT INTO "ORDER"(order_id,customer_id,waiter_id,table_id,order_status)'
                ' VALUES (%s,%s,%s,%s,%s)',
                (nid, cid, wid, tid, self._ins_status.get())
            )
            messagebox.showinfo('Success', f'Order #{nid} inserted.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- UPDATE ------------------------------------------------------- #
    def _build_update(self, p):
        lbl(p, 'Order ID  (load then edit)')
        frm = ctk.CTkFrame(p, fg_color='transparent')
        frm.pack(fill='x', padx=14)
        self._upd_id = ctk.StringVar()
        ctk.CTkEntry(frm, textvariable=self._upd_id,
                      placeholder_text='Order ID', height=36).pack(side='left', fill='x', expand=True)
        ctk.CTkButton(frm, text='Load', width=56, height=36,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self._load_upd).pack(side='left', padx=(4, 0))

        lbl(p, 'Customer ID')
        self._upd_cid = ctk.StringVar()
        self._upd_cid_e = entry(p, self._upd_cid)

        lbl(p, 'Waiter ID')
        self._upd_wid = ctk.StringVar()
        self._upd_wid_e = entry(p, self._upd_wid)

        lbl(p, 'Table ID')
        self._upd_tid = ctk.StringVar()
        self._upd_tid_e = entry(p, self._upd_tid)

        lbl(p, 'Status')
        self._upd_status = ctk.CTkOptionMenu(p, values=list(STATUSES), dynamic_resizing=False)
        self._upd_status.pack(fill='x', padx=14)

        btn(p, '✏️  Update Order', COLORS['warning'], self._do_update)

    def _load_upd(self):
        oid_s = self._upd_id.get().strip()
        if not oid_s.isdigit():
            messagebox.showerror('Input Error', 'Enter a numeric Order ID.')
            return
        row = self._db.fetchone(
            'SELECT order_id,customer_id,waiter_id,table_id,order_status'
            ' FROM "ORDER" WHERE order_id=%s', (int(oid_s),))
        if not row:
            messagebox.showwarning('Not Found', f'No order #{oid_s}.')
            return
        self._upd_cid.set(str(row['customer_id'] or ''))
        self._upd_wid.set(str(row['waiter_id']))
        self._upd_tid.set(str(row['table_id']))
        self._upd_status.set(row['order_status'])

    def _do_update(self):
        oid_s = self._upd_id.get().strip()
        if not oid_s.isdigit():
            messagebox.showerror('Input Error', 'Load an order first.')
            return
        try:
            cid = int(self._upd_cid.get()) if self._upd_cid.get().strip() else None
            wid = int(self._upd_wid.get())
            tid = int(self._upd_tid.get())
        except ValueError:
            messagebox.showerror('Input Error', 'Waiter ID and Table ID must be integers.')
            return
        try:
            rc = self._db.execute(
                'UPDATE "ORDER" SET customer_id=%s,waiter_id=%s,table_id=%s,order_status=%s'
                ' WHERE order_id=%s',
                (cid, wid, tid, self._upd_status.get(), int(oid_s))
            )
            messagebox.showinfo('Success', 'Order updated.' if rc else 'No changes made.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- DELETE ------------------------------------------------------- #
    def _build_delete(self, p):
        lbl(p, 'Order ID  (click row or enter)')
        self._del_id = ctk.StringVar()
        entry(p, self._del_id, 'Order ID')
        ctk.CTkLabel(p, text='⚠️  Deletes the order and all its items.',
                     text_color=COLORS['warning'],
                     font=ctk.CTkFont(size=11)).pack(padx=14, pady=6)
        btn(p, '🗑️  Delete Order', COLORS['danger'], self._do_delete,
            hover=COLORS['primary_hov'])

    def _do_delete(self):
        oid_s = self._del_id.get().strip()
        if not oid_s.isdigit():
            messagebox.showerror('Input Error', 'Enter or select an Order ID.')
            return
        if not messagebox.askyesno('Confirm', f'Delete order #{oid_s} and all items?'):
            return
        try:
            rc = self._db.execute('DELETE FROM "ORDER" WHERE order_id=%s', (int(oid_s),))
            messagebox.showinfo('Deleted', f'Order #{oid_s} deleted.' if rc else 'Not found.')
            self._del_id.set('')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))
