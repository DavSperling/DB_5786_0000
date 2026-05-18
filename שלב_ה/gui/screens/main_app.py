import customtkinter as ctk
from config import APP_NAME, COLORS
from .dashboard  import DashboardScreen
from .orders     import OrdersScreen
from .items      import ItemsScreen
from .bills      import BillsScreen
from .payments   import PaymentsScreen
from .discounts  import DiscountsScreen
from .customers  import CustomersScreen
from .queries    import QueriesScreen
from .programs   import ProgramsScreen

_NAV = [
    ('🏠', 'Dashboard',      'dashboard'),
    ('📋', 'Orders',          'orders'),
    ('🍽️', 'Order Items',    'items'),
    ('🧾', 'Bills',           'bills'),
    ('💳', 'Payments',        'payments'),
    ('🏷️', 'Discounts',      'discounts'),
    ('👥', 'Customers',       'customers'),
    ('🔍', 'Queries',         'queries'),
    ('⚙️', 'Programs',        'programs'),
]


class MainApp(ctk.CTkFrame):
    def __init__(self, parent, username: str, db, logout_cb):
        super().__init__(parent, fg_color=COLORS['content_bg'])
        self._db       = db
        self._username = username
        self._logout   = logout_cb
        self._screens: dict = {}
        self._nav_btns: dict[str, ctk.CTkButton] = {}
        self._build()
        self._show('dashboard')

    # ------------------------------------------------------------------ #
    def _build(self):
        # Sidebar
        sb = ctk.CTkFrame(self, fg_color=COLORS['sidebar_bg'], width=210, corner_radius=0)
        sb.pack(side='left', fill='y')
        sb.pack_propagate(False)

        # Logo
        logo = ctk.CTkFrame(sb, fg_color='transparent')
        logo.pack(fill='x', padx=14, pady=(22, 12))
        ctk.CTkLabel(logo, text='🍽️  ' + APP_NAME,
                     font=ctk.CTkFont(size=13, weight='bold'),
                     text_color=COLORS['secondary']).pack(anchor='w')
        ctk.CTkLabel(logo, text=f'  {self._username}',
                     font=ctk.CTkFont(size=11),
                     text_color=COLORS['text_dim']).pack(anchor='w')

        ctk.CTkFrame(sb, height=1, fg_color=COLORS['border']).pack(fill='x', padx=10, pady=4)

        # Nav buttons
        for icon, label, key in _NAV:
            btn = ctk.CTkButton(
                sb, text=f'{icon}  {label}', anchor='w', height=40,
                fg_color='transparent', hover_color=COLORS['card_bg'],
                text_color=COLORS['text_main'],
                font=ctk.CTkFont(size=13), corner_radius=8,
                command=lambda k=key: self._show(k)
            )
            btn.pack(fill='x', padx=10, pady=2)
            self._nav_btns[key] = btn

        # Logout at bottom
        ctk.CTkFrame(sb, height=1, fg_color=COLORS['border']).pack(
            fill='x', padx=10, pady=4, side='bottom')
        ctk.CTkButton(
            sb, text='🚪  Logout', anchor='w', height=40,
            fg_color='transparent', hover_color='#3D0000',
            text_color='#E74C3C', font=ctk.CTkFont(size=13),
            corner_radius=8, command=self._logout
        ).pack(fill='x', padx=10, pady=(0, 16), side='bottom')

        # Content area
        self._content = ctk.CTkFrame(self, fg_color=COLORS['content_bg'])
        self._content.pack(side='left', fill='both', expand=True)

    def _show(self, key: str):
        for w in self._content.winfo_children():
            w.pack_forget()

        # Highlight active nav
        for k, btn in self._nav_btns.items():
            if k == key:
                btn.configure(fg_color=COLORS['card_bg'],
                               text_color=COLORS['secondary'])
            else:
                btn.configure(fg_color='transparent',
                               text_color=COLORS['text_main'])

        if key not in self._screens:
            self._screens[key] = self._make_screen(key)

        screen = self._screens[key]
        if hasattr(screen, 'refresh'):
            screen.refresh()
        screen.pack(fill='both', expand=True)

    def _make_screen(self, key: str):
        mapping = {
            'dashboard': DashboardScreen,
            'orders':    OrdersScreen,
            'items':     ItemsScreen,
            'bills':     BillsScreen,
            'payments':  PaymentsScreen,
            'discounts': DiscountsScreen,
            'customers': CustomersScreen,
            'queries':   QueriesScreen,
            'programs':  ProgramsScreen,
        }
        cls = mapping[key]
        return cls(self._content, self._db)
