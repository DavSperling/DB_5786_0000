from tkinter import messagebox
import customtkinter as ctk
from .widgets import make_tree, lbl, entry, btn, section_header, split_layout, tabview
from config import COLORS


class ItemsScreen(ctk.CTkFrame):
    def __init__(self, parent, db):
        super().__init__(parent, fg_color='transparent')
        self._db = db
        self._build()
        self.refresh()

    def refresh(self):
        self._tree.delete(*self._tree.get_children())
        try:
            rows = self._db.fetchall("""
                SELECT oi.order_item_id,
                       oi.order_id,
                       TO_CHAR(o.order_time,'YYYY-MM-DD HH24:MI') AS order_time,
                       'Item #' || oi.menu_item_id AS menu_item,
                       oi.quantity,
                       COALESCE(oi.special_request, '—') AS special_request
                FROM order_item oi
                JOIN "ORDER" o ON oi.order_id = o.order_id
                ORDER BY oi.order_item_id DESC LIMIT 500
            """)
            for r in rows:
                self._tree.insert('', 'end', iid=str(r['order_item_id']),
                                  values=(r['order_item_id'], r['order_id'],
                                          r['order_time'], r['menu_item'],
                                          r['quantity'], r['special_request']))
        except Exception as e:
            messagebox.showerror('Load Error', str(e))

    def _build(self):
        hdr = section_header(self, '🍽️', 'Order Items')
        ctk.CTkButton(hdr, text='⟳ Refresh', width=90, height=32,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self.refresh).pack(side='right')

        left, right = split_layout(self)
        self._tree = make_tree(
            left,
            columns=('item_id', 'order_id', 'order_time', 'menu_item', 'qty', 'special'),
            headings={'item_id': 'ID', 'order_id': 'Order', 'order_time': 'Order Time',
                      'menu_item': 'Menu Item', 'qty': 'Qty', 'special': 'Special Request'},
            widths={'order_time': 135, 'menu_item': 90, 'special': 180}
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
        lbl(p, 'Order ID *')
        self._ins_oid = ctk.StringVar()
        entry(p, self._ins_oid, 'e.g. 1001')

        lbl(p, 'Menu Item ID *')
        self._ins_mid = ctk.StringVar()
        entry(p, self._ins_mid, 'e.g. 5')

        lbl(p, 'Quantity *')
        self._ins_qty = ctk.StringVar(value='1')
        entry(p, self._ins_qty, '1')

        lbl(p, 'Special Request')
        self._ins_special = ctk.StringVar()
        entry(p, self._ins_special, 'e.g. No onions')

        btn(p, '➕  Insert Item', COLORS['success'], self._do_insert,
            hover=COLORS['success_hov'])

    def _do_insert(self):
        try:
            oid = int(self._ins_oid.get())
            mid = int(self._ins_mid.get())
            qty = int(self._ins_qty.get())
            if qty <= 0:
                raise ValueError('Quantity must be > 0')
        except ValueError as e:
            messagebox.showerror('Input Error', str(e))
            return
        special = self._ins_special.get().strip() or None
        try:
            nid = self._db.next_id('order_item', 'order_item_id')
            self._db.execute(
                'INSERT INTO order_item(order_item_id,order_id,menu_item_id,quantity,special_request)'
                ' VALUES (%s,%s,%s,%s,%s)',
                (nid, oid, mid, qty, special)
            )
            messagebox.showinfo('Success', f'Item #{nid} inserted.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- UPDATE ------------------------------------------------------- #
    def _build_update(self, p):
        lbl(p, 'Item ID  (load then edit)')
        frm = ctk.CTkFrame(p, fg_color='transparent')
        frm.pack(fill='x', padx=14)
        self._upd_id = ctk.StringVar()
        ctk.CTkEntry(frm, textvariable=self._upd_id,
                      placeholder_text='Item ID', height=36).pack(side='left', fill='x', expand=True)
        ctk.CTkButton(frm, text='Load', width=56, height=36,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self._load_upd).pack(side='left', padx=(4, 0))

        lbl(p, 'Menu Item ID')
        self._upd_mid = ctk.StringVar()
        entry(p, self._upd_mid)

        lbl(p, 'Quantity')
        self._upd_qty = ctk.StringVar()
        entry(p, self._upd_qty)

        lbl(p, 'Special Request')
        self._upd_special = ctk.StringVar()
        entry(p, self._upd_special)

        btn(p, '✏️  Update Item', COLORS['warning'], self._do_update)

    def _load_upd(self):
        iid_s = self._upd_id.get().strip()
        if not iid_s.isdigit():
            messagebox.showerror('Input Error', 'Enter a numeric Item ID.')
            return
        row = self._db.fetchone(
            'SELECT order_item_id,menu_item_id,quantity,special_request'
            ' FROM order_item WHERE order_item_id=%s', (int(iid_s),))
        if not row:
            messagebox.showwarning('Not Found', f'No item #{iid_s}.')
            return
        self._upd_mid.set(str(row['menu_item_id']))
        self._upd_qty.set(str(row['quantity']))
        self._upd_special.set(row['special_request'] or '')

    def _do_update(self):
        iid_s = self._upd_id.get().strip()
        if not iid_s.isdigit():
            messagebox.showerror('Input Error', 'Load an item first.')
            return
        try:
            mid = int(self._upd_mid.get())
            qty = int(self._upd_qty.get())
        except ValueError:
            messagebox.showerror('Input Error', 'Menu Item ID and Quantity must be integers.')
            return
        special = self._upd_special.get().strip() or None
        try:
            rc = self._db.execute(
                'UPDATE order_item SET menu_item_id=%s,quantity=%s,special_request=%s'
                ' WHERE order_item_id=%s',
                (mid, qty, special, int(iid_s))
            )
            messagebox.showinfo('Success', 'Item updated.' if rc else 'No changes.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- DELETE ------------------------------------------------------- #
    def _build_delete(self, p):
        lbl(p, 'Item ID  (click row or enter)')
        self._del_id = ctk.StringVar()
        entry(p, self._del_id, 'Item ID')
        btn(p, '🗑️  Delete Item', COLORS['danger'], self._do_delete,
            hover=COLORS['primary_hov'])

    def _do_delete(self):
        iid_s = self._del_id.get().strip()
        if not iid_s.isdigit():
            messagebox.showerror('Input Error', 'Enter or select an Item ID.')
            return
        if not messagebox.askyesno('Confirm', f'Delete item #{iid_s}?'):
            return
        try:
            rc = self._db.execute('DELETE FROM order_item WHERE order_item_id=%s', (int(iid_s),))
            messagebox.showinfo('Deleted', 'Item deleted.' if rc else 'Not found.')
            self._del_id.set('')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))
