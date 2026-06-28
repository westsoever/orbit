# macOS Accessibility Permissions

To allow the capture daemon to read the accessibility tree:

System Settings → Privacy & Security → Accessibility → toggle on your Terminal app (or the Python interpreter process).

You may need to add the terminal manually via the "+" button if it does not appear in the list.

After granting permission, restart the terminal session and re-run:

```bash
source .venv/bin/activate
orbit start
```

## Python / SQLite (separate from Accessibility)

Embeddings require loadable SQLite extensions. After creating the venv (see README), verify:

```bash
python -c "import sqlite3; sqlite3.connect(':memory:').enable_load_extension(True)"
```

Use `python` from the activated venv, not system `python3`. If verification fails, run `orbit start --no-embed` for capture-only mode.
