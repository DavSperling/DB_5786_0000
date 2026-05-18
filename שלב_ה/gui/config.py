import os
import hashlib
from pathlib import Path


def _load_env(path: Path) -> None:
    if not path.exists():
        return
    with path.open() as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, _, val = line.partition('=')
            os.environ.setdefault(key.strip(), val.strip())


# Walk up to project root (.env lives 3 levels above gui/)
_load_env(Path(__file__).parent.parent.parent / '.env')

DB_CONFIG: dict = {
    'host':            os.getenv('DB_HOST',           'localhost'),
    'port':            int(os.getenv('DB_PORT',       '5433')),
    'database':        os.getenv('DB_NAME_SECRET',    'restaurant_db'),
    'user':            os.getenv('DB_USER_SECRET',    'admin'),
    'password':        os.getenv('DB_PASSWORD_SECRET','admin123'),
    'connect_timeout': 10,
}

APP_NAME    = 'La Bella Cucina OS'
APP_VERSION = '2.0'
APP_TAGLINE = 'All-Purpose Order System'


def _sha256(pw: str) -> str:
    return hashlib.sha256(pw.encode('utf-8')).hexdigest()


# Credential store — hashed with SHA-256 (production: use bcrypt + DB)
APP_CREDENTIALS: dict[str, str] = {
    'admin':   _sha256('admin123'),
    'manager': _sha256('manager123'),
}

COLORS = {
    'primary':     '#C0392B',
    'primary_hov': '#922B21',
    'secondary':   '#D4AC0D',
    'sidebar_bg':  '#1A1A2E',
    'content_bg':  '#16213E',
    'card_bg':     '#0F3460',
    'text_main':   '#EAEAEA',
    'text_dim':    '#9BA4B5',
    'success':     '#27AE60',
    'success_hov': '#1E8449',
    'warning':     '#E67E22',
    'danger':      '#C0392B',
    'border':      '#2D4059',
    'row_alt':     '#112244',
}
