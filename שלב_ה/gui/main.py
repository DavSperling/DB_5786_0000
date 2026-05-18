"""La Bella Cucina OS — Entry point."""
import sys
from tkinter import messagebox
import customtkinter as ctk

ctk.set_appearance_mode('dark')
ctk.set_default_color_theme('dark-blue')

import db as db_module
from config import APP_NAME, APP_VERSION
from screens.login    import LoginScreen
from screens.main_app import MainApp


class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title(f'{APP_NAME}  v{APP_VERSION}')
        self.geometry('1280x780')
        self.minsize(1040, 660)

        self._db = db_module.DBManager()
        try:
            self._db.connect()
        except Exception as e:
            messagebox.showerror('Connection Error',
                                  f'Cannot connect to the database.\n\n{e}\n\n'
                                  'Make sure Docker is running:\n  docker-compose up -d')
            sys.exit(1)

        self._frame: ctk.CTkFrame | None = None
        self._show_login()
        self.protocol('WM_DELETE_WINDOW', self._on_close)

    def _swap(self, frame: ctk.CTkFrame):
        if self._frame:
            self._frame.destroy()
        self._frame = frame
        frame.pack(fill='both', expand=True)

    def _show_login(self):
        self._swap(LoginScreen(self, self._on_login))

    def _on_login(self, username: str):
        self._swap(MainApp(self, username, self._db, self._show_login))

    def _on_close(self):
        self._db.disconnect()
        self.destroy()


if __name__ == '__main__':
    App().mainloop()
