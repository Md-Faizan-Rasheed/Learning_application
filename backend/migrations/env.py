import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from alembic import context

config = context.config

# Pull the DB URL from the environment so credentials are never hardcoded.
#
# IMPORTANT: use the DIRECT (non-pooled) connection string for migrations.
# Running DDL through a PgBouncer/pooled endpoint in transaction-pooling
# mode can silently no-op — the same class of bug that bit the earlier
# Drizzle setup. Point DATABASE_URL at the direct host for migrations.
db_url = os.getenv("DATABASE_URL")
if db_url:
    # SQLAlchemy wants an explicit driver; normalise a bare postgres:// URL.
    if db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql+psycopg2://", 1)
    elif db_url.startswith("postgresql://"):
        db_url = db_url.replace("postgresql://", "postgresql+psycopg2://", 1)
    config.set_main_option("sqlalchemy.url", db_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# No ORM models yet — migrations are hand-written. If you later adopt
# SQLAlchemy models, set: target_metadata = Base.metadata  (enables
# --autogenerate).
target_metadata = None


def run_migrations_offline() -> None:
    """Emit SQL to stdout without a live DB connection (`alembic upgrade head --sql`)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations against a live database connection."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
