from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """App configuration, read from environment / .env. No secrets in code."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    env: str = "development"
    database_url: str = "postgresql://postgres:postgres@localhost:5432/game"
    redis_url: str = "redis://localhost:6379/0"

    # JWT signing. No default on purpose — a missing secret should fail the
    # app's startup loudly, not silently fall back to a value that's sitting
    # in this file in plain text (that's exactly what happened here before:
    # every token this app ever issued locally was signed with a hardcoded
    # placeholder secret because .env never set a real one).
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_ttl_days: int = 7

    # Backend-only secret for the teacher AI question-import feature. Never
    # sent to the client. Unset -> the ai-import endpoint returns 503.
    openai_api_key: str | None = None
    openai_model: str = "gpt-4o-mini"

    # Transactional email for password-reset links. Unset -> the reset link
    # is logged server-side instead of emailed (still fully testable, just
    # not delivered to a real inbox until this is configured).
    resend_api_key: str | None = None
    email_from: str = "onboarding@resend.dev"

    # Crash/error reporting. Unset -> Sentry's SDK no-ops (its own documented
    # behavior for a None DSN), so this is safe to leave unconfigured.
    sentry_dsn: str | None = None

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