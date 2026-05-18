from tkinter import messagebox
import customtkinter as ctk
from .widgets import make_tree, lbl, entry, btn, section_header, split_layout, tabview
from config import COLORS


class DiscountsScreen(ctk.CTkFrame):
    def __init__(self, parent, db):
        super().__init__(parent, fg_color='transparent')
        self._db = db
        self._build()
        self.refresh()

    def refresh(self):
        self._tree.delete(*self._tree.get_children())
        try:
            rows = self._db.fetchall("""
                SELECT d.discount_id,
                       d.discount_name,
                       d.percentage,
                       TO_CHAR(d.valid_from,'YYYY-MM-DD') AS valid_from,
                       TO_CHAR(d.valid_to,'YYYY-MM-DD')   AS valid_to,
                       (d.valid_to - d.valid_from)        AS days
                FROM discount d
                ORDER BY d.percentage DESC
            """)
            for r in rows:
                self._tree.insert('', 'end', iid=str(r['discount_id']),
                                  values=(r['discount_id'], r['discount_name'],
                                          f"{float(r['percentage']):.1f}%",
                                          r['valid_from'], r['valid_to'], r['days']))
        except Exception as e:
            messagebox.showerror('Load Error', str(e))

    def _build(self):
        hdr = section_header(self, '🏷️', 'Discounts')
        ctk.CTkButton(hdr, text='⟳ Refresh', width=90, height=32,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self.refresh).pack(side='right')

        left, right = split_layout(self)
        self._tree = make_tree(
            left,
            columns=('disc_id', 'name', 'pct', 'from_d', 'to_d', 'days'),
            headings={'disc_id': 'ID', 'name': 'Name', 'pct': '%',
                      'from_d': 'Valid From', 'to_d': 'Valid To', 'days': 'Days'},
            widths={'name': 180, 'from_d': 100, 'to_d': 100}
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
        lbl(p, 'Name *')
        self._ins_name = ctk.StringVar()
        entry(p, self._ins_name, 'e.g. Summer Deal')

        lbl(p, 'Percentage *  (0 – 100)')
        self._ins_pct = ctk.StringVar()
        entry(p, self._ins_pct, 'e.g. 15')

        lbl(p, 'Valid From *  (YYYY-MM-DD)')
        self._ins_from = ctk.StringVar()
        entry(p, self._ins_from, '2025-01-01')

        lbl(p, 'Valid To *  (YYYY-MM-DD)')
        self._ins_to = ctk.StringVar()
        entry(p, self._ins_to, '2025-12-31')

        btn(p, '➕  Insert Discount', COLORS['success'], self._do_insert,
            hover=COLORS['success_hov'])

    def _do_insert(self):
        name = self._ins_name.get().strip()
        if not name:
            messagebox.showerror('Input Error', 'Name is required.')
            return
        try:
            pct  = float(self._ins_pct.get())
            if not 0 <= pct <= 100:
                raise ValueError('Percentage must be 0–100')
        except ValueError as e:
            messagebox.showerror('Input Error', str(e))
            return
        vf = self._ins_from.get().strip()
        vt = self._ins_to.get().strip()
        try:
            nid = self._db.next_id('discount', 'discount_id')
            self._db.execute(
                'INSERT INTO discount(discount_id,discount_name,percentage,valid_from,valid_to)'
                ' VALUES (%s,%s,%s,%s,%s)',
                (nid, name, pct, vf, vt)
            )
            messagebox.showinfo('Success', f'Discount #{nid} inserted.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- UPDATE ------------------------------------------------------- #
    def _build_update(self, p):
        lbl(p, 'Discount ID  (load then edit)')
        frm = ctk.CTkFrame(p, fg_color='transparent')
        frm.pack(fill='x', padx=14)
        self._upd_id = ctk.StringVar()
        ctk.CTkEntry(frm, textvariable=self._upd_id,
                      placeholder_text='Discount ID', height=36).pack(side='left', fill='x', expand=True)
        ctk.CTkButton(frm, text='Load', width=56, height=36,
                       fg_color=COLORS['card_bg'], hover_color=COLORS['border'],
                       command=self._load_upd).pack(side='left', padx=(4, 0))

        lbl(p, 'Name')
        self._upd_name = ctk.StringVar()
        entry(p, self._upd_name)

        lbl(p, 'Percentage')
        self._upd_pct = ctk.StringVar()
        entry(p, self._upd_pct)

        lbl(p, 'Valid From')
        self._upd_from = ctk.StringVar()
        entry(p, self._upd_from)

        lbl(p, 'Valid To')
        self._upd_to = ctk.StringVar()
        entry(p, self._upd_to)

        btn(p, '✏️  Update Discount', COLORS['warning'], self._do_update)

    def _load_upd(self):
        did_s = self._upd_id.get().strip()
        if not did_s.isdigit():
            messagebox.showerror('Input Error', 'Enter a numeric Discount ID.')
            return
        row = self._db.fetchone(
            'SELECT discount_id,discount_name,percentage,valid_from,valid_to'
            ' FROM discount WHERE discount_id=%s', (int(did_s),))
        if not row:
            messagebox.showwarning('Not Found', f'No discount #{did_s}.')
            return
        self._upd_name.set(row['discount_name'])
        self._upd_pct.set(str(row['percentage']))
        self._upd_from.set(str(row['valid_from']))
        self._upd_to.set(str(row['valid_to']))

    def _do_update(self):
        did_s = self._upd_id.get().strip()
        if not did_s.isdigit():
            messagebox.showerror('Input Error', 'Load a discount first.')
            return
        try:
            pct = float(self._upd_pct.get())
        except ValueError:
            messagebox.showerror('Input Error', 'Percentage must be numeric.')
            return
        try:
            rc = self._db.execute(
                'UPDATE discount SET discount_name=%s,percentage=%s,valid_from=%s,valid_to=%s'
                ' WHERE discount_id=%s',
                (self._upd_name.get(), pct,
                 self._upd_from.get(), self._upd_to.get(), int(did_s))
            )
            messagebox.showinfo('Success', 'Discount updated.' if rc else 'No changes.')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))

    # ---- DELETE ------------------------------------------------------- #
    def _build_delete(self, p):
        lbl(p, 'Discount ID  (click row or enter)')
        self._del_id = ctk.StringVar()
        entry(p, self._del_id, 'Discount ID')
        btn(p, '🗑️  Delete Discount', COLORS['danger'], self._do_delete,
            hover=COLORS['primary_hov'])

    def _do_delete(self):
        did_s = self._del_id.get().strip()
        if not did_s.isdigit():
            messagebox.showerror('Input Error', 'Enter or select a Discount ID.')
            return
        if not messagebox.askyesno('Confirm', f'Delete discount #{did_s}?'):
            return
        try:
            self._db.execute('DELETE FROM bill_discount WHERE discount_id=%s', (int(did_s),))
            rc = self._db.execute('DELETE FROM discount WHERE discount_id=%s', (int(did_s),))
            messagebox.showinfo('Deleted', 'Discount deleted.' if rc else 'Not found.')
            self._del_id.set('')
            self.refresh()
        except Exception as e:
            messagebox.showerror('DB Error', str(e))
