import hashlib
import customtkinter as ctk
from config import APP_NAME, APP_TAGLINE, APP_CREDENTIALS, COLORS


class LoginScreen(ctk.CTkFrame):
    def __init__(self, parent, on_success):
        super().__init__(parent, fg_color=COLORS['sidebar_bg'])
        self._on_success = on_success
        self._build()

    def _build(self):
        card = ctk.CTkFrame(self, fg_color=COLORS['card_bg'], corner_radius=20,
                             width=420, height=520)
        card.place(relx=0.5, rely=0.5, anchor='center')
        card.pack_propagate(False)

        ctk.CTkLabel(card, text='🍽️', font=ctk.CTkFont(size=56)).pack(pady=(38, 4))
        ctk.CTkLabel(card, text=APP_NAME,
                     font=ctk.CTkFont(size=20, weight='bold'),
                     text_color=COLORS['secondary']).pack()
        ctk.CTkLabel(card, text=APP_TAGLINE,
                     font=ctk.CTkFont(size=11),
                     text_color=COLORS['text_dim']).pack(pady=(2, 28))

        # Username
        ctk.CTkLabel(card, text='Username', anchor='w',
                     text_color=COLORS['text_dim']).pack(fill='x', padx=44)
        self._user = ctk.StringVar()
        u_entry = ctk.CTkEntry(card, textvariable=self._user,
                                placeholder_text='admin', height=40, corner_radius=8)
        u_entry.pack(fill='x', padx=44, pady=(3, 14))

        # Password
        ctk.CTkLabel(card, text='Password', anchor='w',
                     text_color=COLORS['text_dim']).pack(fill='x', padx=44)
        self._pw = ctk.StringVar()
        p_entry = ctk.CTkEntry(card, textvariable=self._pw, show='•',
                                placeholder_text='••••••••', height=40, corner_radius=8)
        p_entry.pack(fill='x', padx=44, pady=(3, 22))
        p_entry.bind('<Return>', lambda _: self._login())

        ctk.CTkButton(card, text='Sign In', height=44, corner_radius=10,
                       fg_color=COLORS['primary'], hover_color=COLORS['primary_hov'],
                       font=ctk.CTkFont(size=14, weight='bold'),
                       command=self._login).pack(fill='x', padx=44)

        self._err = ctk.StringVar()
        ctk.CTkLabel(card, textvariable=self._err,
                     text_color='#E74C3C',
                     font=ctk.CTkFont(size=11)).pack(pady=(8, 0))

        ctk.CTkLabel(card, text='Default: admin / admin123',
                     font=ctk.CTkFont(size=10),
                     text_color=COLORS['text_dim']).pack(pady=(4, 20))

        u_entry.focus()

    def _login(self):
        user = self._user.get().strip().lower()
        pw   = self._pw.get()
        if not user or not pw:
            self._err.set('Please enter both fields.')
            return
        hashed = hashlib.sha256(pw.encode()).hexdigest()
        if APP_CREDENTIALS.get(user) == hashed:
            self._on_success(user)
        else:
            self._err.set('Invalid credentials.')
            self._pw.set('')
