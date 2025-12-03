# Copilot / AI Agent Instructions

Keep this document short and actionable — what an AI coding agent needs to be productive in this repository.

Overview
- **Purpose:** Python ETL + dbt project that reads Google Sheets, writes to Postgres, and runs dbt models (bronze → silver → gold). Main orchestration lives in `dags/`.
- **Key directories:** `dags/` (scripts + `lib/` helpers), `fdw_dbt/` (dbt project), `dags/queries/table_creation/` (DDL SQL files).
- **Database schemas used:** `bronze`, `silver`, `gold` (convention across SQL and code).

How the pieces fit
- `dags/*.py` are runnable scripts that: read from Google Sheets (`dags/lib/google_lib.py`), transform (pandas), and write to Postgres using `dags/lib/postgresql_lib.py`.
- `dags/lib/postgresql_lib.py` handles DB connections (reads env vars), executes SQL or SQL files, and provides `insert_df()` which generates SQL and writes `queries/debug_query.sql` before executing.
- `fdw_dbt/` contains dbt models and seeds. Scripts call dbt through Python using `dbt.cli.main.dbtRunner`.
- `dags/lib/constants.py` stores Google sheet IDs and mapping between `sheets` and `db` target tables.

Environment & secrets
- Environment variables (required): `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_DATABASE`, `DB_DATABASE_DEV`, `REFRESH_TOKEN`, `GCLOUD_CLIENT_ID`, `GCLOUD_CLIENT_SECRET`.
- Postgres connection uses port `5433` (see `postgresql_lib.execute_query`). Use `target_db='prod'` or `'dev'` to switch DB.
- Google credentials: client JSON is checked in under `dags/lib/client_secret_*.json`. Long-lived `REFRESH_TOKEN` is expected in env; helper `get_refresh_token()` in `google_lib.py` can generate one interactively.

Run / debug patterns (examples)
- Update sources from Google Sheets and run dbt locally:
  - `python dags/daily_update.py` (this reads sheets, truncates bronze tables, inserts, runs dbt checks)
- Recreate bronze tables locally (reads SQL files under `dags/queries/table_creation`):
  - `python dags/lib/postgresql_lib.py` (call `recreate_tables()` or run script directly)
- Run dbt from Python (existing scripts use dbtRunner): ensure `fdw_dbt` path is correct; some scripts have hardcoded Windows paths like `F:\Backup\Projects\FDW\fdw_dbt` — prefer `SCRIPT_DIR / 'fdw_dbt'` used in `daily_update.py`.

Project-specific conventions
- Avoid changing SQL schema names — `bronze`, `silver`, `gold` are used in code and dbt models.
- `postgresql_lib.execute_query(query_name, code=False, mode='select', target_db='prod')`:
  - `code=True` : `query_name` is raw SQL code string
  - `code=False`: `query_name` is a file path to read
  - `mode='write'` commits changes
- `insert_df(df, table, merge=False, target_db='prod')` writes a debug SQL to `queries/debug_query.sql` before executing; useful for inspecting generated SQL.
- Date utilities: use `dags/lib/utils.date_add()` to manipulate dates consistently across scripts.

Integration notes & pitfalls
- Watch for Windows-hardcoded paths (absolute `F:\...`) in several scripts — update to use `Path(__file__).resolve().parent` pattern when modifying code.
- DB port is `5433` (non-standard). Tests and runners should respect this port or read `postgresql_lib` connection logic.
- Google API uses `google-auth` flow. If running headless, ensure `REFRESH_TOKEN` and client id/secret are set; otherwise use `get_refresh_token()` locally.
- dbt is invoked via Python `dbtRunner`. Ensure the environment has `dbt` installed and `fdw_dbt` path is reachable.

Files to inspect for examples
- `dags/daily_update.py` — end-to-end orchestration example (sheets → DB → dbt → validations)
- `dags/lib/postgresql_lib.py` — DB interaction patterns and generated SQL behavior
- `dags/lib/google_lib.py` — Google Sheets read/write and credential handling
- `dags/lib/constants.py` — sheet IDs and table mapping
- `dags/projections.py`, `dags/allocation_simulation.py`, `dags/income_tax_update.py` — data transformation examples and dbt invocation patterns

What an agent should do first
- Read `dags/daily_update.py` to understand the happy-path orchestration.
- Inspect `dags/lib/postgresql_lib.py` and `dags/lib/google_lib.py` for I/O side effects and env var requirements.
- When changing file paths, replace hardcoded Windows paths with `Path(__file__).resolve().parent` to keep scripts portable.

If something is unclear
- Ask which environment to target (local dev vs prod) and whether a valid `.env` with DB and Google credentials is available.

Requested feedback
- Tell me which areas you'd like expanded (dbt workflows, credentials, or SQL conventions) and I will iterate.
