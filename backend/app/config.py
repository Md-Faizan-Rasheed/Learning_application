from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """App configuration, read from environment / .env. No secrets in code."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "development"
    database_url: str = "postgresql://postgres:postgres@localhost:5432/game"
    redis_url: str = "redis://localhost:6379/0"

    # TODO(auth-epic): temporary admin gate. Replace with proper role-based
    # auth once the Auth epic lands. For now, admin content endpoints require
    # this key in the `X-Admin-Key` header.
    admin_api_key: str = "dev-admin-key-change-me"

    @property
    def async_database_url(self) -> str:
        """The app talks to Postgres over asyncpg; normalise the URL for it.

        (Alembic uses a sync psycopg2 URL instead — see migrations/env.py.)
        """
        url = self.database_url
        if url.startswith("postgres://"):
            return url.replace("postgres://", "postgresql+asyncpg://", 1)
        if url.startswith("postgresql://"):
            return url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return url


settings = Settings()