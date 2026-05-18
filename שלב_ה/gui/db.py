import psycopg2
import psycopg2.extras
from typing import Any
from config import DB_CONFIG


class DBManager:
    def __init__(self):
        self._conn: psycopg2.extensions.connection | None = None

    # ------------------------------------------------------------------ #
    #  Connection
    # ------------------------------------------------------------------ #
    def connect(self) -> None:
        self._conn = psycopg2.connect(**DB_CONFIG)
        self._conn.autocommit = False

    def disconnect(self) -> None:
        if self._conn and not self._conn.closed:
            try:
                self._conn.close()
            except Exception:
                pass
        self._conn = None

    def _ensure(self) -> None:
        if self._conn is None or self._conn.closed:
            self.connect()
            return
        try:
            with self._conn.cursor() as cur:
                cur.execute("SELECT 1")
        except psycopg2.OperationalError:
            self.connect()

    # ------------------------------------------------------------------ #
    #  Read helpers
    # ------------------------------------------------------------------ #
    def fetchall(self, sql: str, params: tuple = ()) -> list[dict]:
        self._ensure()
        with self._conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            return [dict(r) for r in cur.fetchall()]

    def fetchone(self, sql: str, params: tuple = ()) -> dict | None:
        self._ensure()
        with self._conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            row = cur.fetchone()
            return dict(row) if row else None

    # ------------------------------------------------------------------ #
    #  Write helpers
    # ------------------------------------------------------------------ #
    def execute(self, sql: str, params: tuple = ()) -> int:
        """Execute INSERT/UPDATE/DELETE; return rowcount."""
        self._ensure()
        try:
            with self._conn.cursor() as cur:
                cur.execute(sql, params)
                rc = cur.rowcount
            self._conn.commit()
            return rc
        except Exception:
            self._conn.rollback()
            raise

    def execute_returning(self, sql: str, params: tuple = ()) -> dict | None:
        self._ensure()
        try:
            with self._conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(sql, params)
                row = cur.fetchone()
                result = dict(row) if row else None
            self._conn.commit()
            return result
        except Exception:
            self._conn.rollback()
            raise

    # ------------------------------------------------------------------ #
    #  Stored procedure / function helpers
    # ------------------------------------------------------------------ #
    def call_procedure(self, name: str, params: tuple = ()) -> str:
        """CALL a procedure; return captured NOTICE messages."""
        self._ensure()
        before = len(self._conn.notices)
        try:
            ph = ', '.join(['%s'] * len(params))
            with self._conn.cursor() as cur:
                cur.execute(f"CALL {name}({ph})", params)
            self._conn.commit()
            notes = self._conn.notices[before:]
            return '\n'.join(notes) if notes else f"{name} completed successfully."
        except Exception:
            self._conn.rollback()
            raise

    def call_refcursor_function(self, name: str, params: tuple = ()) -> list[dict]:
        """Call a function that returns a REFCURSOR; fetch all rows."""
        self._ensure()
        try:
            ph = ', '.join(['%s'] * len(params))
            with self._conn.cursor() as cur:
                cur.execute(f"SELECT {name}({ph})", params)
                cursor_name = cur.fetchone()[0]
            with self._conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(f'FETCH ALL IN "{cursor_name}"')
                rows = [dict(r) for r in cur.fetchall()]
            self._conn.commit()
            return rows
        except Exception:
            self._conn.rollback()
            raise

    def call_scalar_function(self, name: str, params: tuple = ()) -> Any:
        """Call a scalar function; return its value."""
        self._ensure()
        try:
            ph = ', '.join(['%s'] * len(params))
            with self._conn.cursor() as cur:
                cur.execute(f"SELECT {name}({ph})", params)
                val = cur.fetchone()[0]
            self._conn.commit()
            return val
        except Exception:
            self._conn.rollback()
            raise

    # ------------------------------------------------------------------ #
    #  Schema helpers
    # ------------------------------------------------------------------ #
    def table_columns(self, table: str) -> list[str]:
        rows = self.fetchall(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema='public' AND table_name=%s "
            "ORDER BY ordinal_position",
            (table.lower(),)
        )
        return [r['column_name'] for r in rows]

    def next_id(self, table: str, pk_col: str) -> int:
        row = self.fetchone(f'SELECT COALESCE(MAX({pk_col}), 0)+1 AS nid FROM {table}')
        return int(row['nid'])
