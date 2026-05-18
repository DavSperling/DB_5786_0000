"""Shared UI helpers used by all CRUD screens."""
from tkinter import ttk
import customtkinter as ctk
from config import COLORS

_STYLE_APPLIED = False


def apply_tree_style() -> None:
    global _STYLE_APPLIED
    if _STYLE_APPLIED:
        return
    _STYLE_APPLIED = True
    s = ttk.Style()
    s.theme_use('default')
    s.configure('DB.Treeview',
                 background=COLORS['card_bg'],
                 foreground=COLORS['text_main'],
                 fieldbackground=COLORS['card_bg'],
                 rowheight=26,
                 font=('Consolas', 10))
    s.configure('DB.Treeview.Heading',
                 background=COLORS['content_bg'],
                 foreground=COLORS['secondary'],
                 relief='flat',
                 font=('Arial', 10, 'bold'))
    s.map('DB.Treeview',
           background=[('selected', COLORS['primary'])],
           foreground=[('selected', '#FFFFFF')])


def make_tree(parent: ctk.CTkFrame,
              columns: tuple[str, ...],
              headings: dict[str, str],
              widths: dict[str, int] | None = None) -> ttk.Treeview:
    apply_tree_style()
    widths = widths or {}
    f = ctk.CTkFrame(parent, fg_color='transparent')
    f.pack(fill='both', expand=True, padx=8, pady=8)

    tree = ttk.Treeview(f, columns=columns, show='headings', style='DB.Treeview')
    for col in columns:
        tree.heading(col, text=headings.get(col, col.replace('_', ' ').title()))
        tree.column(col, width=widths.get(col, 110), anchor='center', stretch=True)

    vsb = ttk.Scrollbar(f, orient='vertical',   command=tree.yview)
    hsb = ttk.Scrollbar(f, orient='horizontal', command=tree.xview)
    tree.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)
    tree.grid(row=0, column=0, sticky='nsew')
    vsb.grid(row=0, column=1, sticky='ns')
    hsb.grid(row=1, column=0, sticky='ew')
    f.rowconfigure(0, weight=1)
    f.columnconfigure(0, weight=1)
    return tree


def lbl(parent, text: str) -> None:
    ctk.CTkLabel(parent, text=text, anchor='w',
                 text_color=COLORS['text_dim'],
                 font=ctk.CTkFont(size=12)).pack(fill='x', padx=14, pady=(7, 1))


def entry(parent, var: ctk.StringVar, placeholder: str = '',
          readonly: bool = False) -> ctk.CTkEntry:
    e = ctk.CTkEntry(parent, textvariable=var,
                      placeholder_text=placeholder,
                      height=36, corner_radius=6,
                      state='disabled' if readonly else 'normal')
    e.pack(fill='x', padx=14)
    return e


def btn(parent, text: str, color: str, cmd,
        hover: str | None = None, pady=(8, 4)) -> ctk.CTkButton:
    b = ctk.CTkButton(parent, text=text, height=38, corner_radius=8,
                       fg_color=color,
                       hover_color=hover or color,
                       command=cmd)
    b.pack(fill='x', padx=14, pady=pady)
    return b


def section_header(parent, icon: str, title: str) -> ctk.CTkFrame:
    hdr = ctk.CTkFrame(parent, fg_color='transparent')
    hdr.pack(fill='x', padx=22, pady=(18, 8))
    ctk.CTkLabel(hdr,
                 text=f'{icon}  {title}',
                 font=ctk.CTkFont(size=22, weight='bold'),
                 text_color=COLORS['text_main']).pack(side='left')
    return hdr


def split_layout(parent) -> tuple[ctk.CTkFrame, ctk.CTkFrame]:
    """Return (left_card, right_card) in a 60/40 split."""
    pane = ctk.CTkFrame(parent, fg_color='transparent')
    pane.pack(fill='both', expand=True, padx=22, pady=(0, 12))
    pane.columnconfigure(0, weight=3)
    pane.columnconfigure(1, weight=2)
    pane.rowconfigure(0, weight=1)

    left = ctk.CTkFrame(pane, fg_color=COLORS['card_bg'], corner_radius=12)
    left.grid(row=0, column=0, sticky='nsew', padx=(0, 6))

    right = ctk.CTkFrame(pane, fg_color=COLORS['card_bg'], corner_radius=12)
    right.grid(row=0, column=1, sticky='nsew')
    return left, right


def tabview(parent) -> ctk.CTkTabview:
    tv = ctk.CTkTabview(
        parent,
        fg_color='transparent',
        segmented_button_fg_color=COLORS['content_bg'],
        segmented_button_selected_color=COLORS['primary'],
        segmented_button_unselected_color=COLORS['content_bg'],
        segmented_button_selected_hover_color=COLORS['primary_hov'],
    )
    tv.pack(fill='both', expand=True, padx=8, pady=8)
    for name in ('Insert', 'Update', 'Delete'):
        tv.add(name)
    return tv
