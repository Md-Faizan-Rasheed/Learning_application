import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .auth.routes import router as auth_router
from .campaign.routes import router as campaign_router
from .classroom.routes import router as classroom_router
from .config import settings
from .content.routes import public_router as content_public_router, router as content_router
from .contributions.routes import router as contributions_router
from .game.routes import router as game_router
from .health.routes import router as health_router
from .legal.routes import router as legal_router
from .moderation.routes import admin_router as moderation_admin_router, router as moderation_router
from .progression.routes import router as profile_router
from .quests.routes import router as quests_router
from .realtime.server import sio
from .social.routes import router as social_router
from .teacher.routes import router as teacher_router
from .telemetry.routes import router as telemetry_router

# A None DSN disables the SDK, but a blank or malformed one makes
# sentry_sdk raise instead of no-op — crash/error reporting is optional and
# must never be able to take the whole API down over a typo'd env var, so
# swallow init failures here rather than let them abort startup.
if settings.sentry_dsn:
    try:
        sentry_sdk.init(dsn=settings.sentry_dsn, environment=settings.env, send_default_pii=False)
    except Exception as exc:
        print(f"Sentry init failed, continuing without it: {exc}")


class UTF8JSONResponse(JSONResponse):
    """Starlette's JSONResponse sends `Content-Type: application/json` with no
    charset. Most HTTP clients then fall back to Latin-1 for decoding (Dart's
    `http` package included), silently mangling any non-ASCII response body
    (Arabic/Urdu question text, names, etc.). Declaring charset=utf-8
    explicitly removes the ambiguity."""

    media_type = "application/json; charset=utf-8"


app = FastAPI(title="Islamic Learning Game API", default_response_class=UTF8JSONResponse)

# CORS: browsers block cross-origin calls, so the Flutter web app can't
# reach this API unless we allow its origin. The deployed production
# frontend and any localhost dev port (a developer's own browser running
# the Flutter web build, often pointed at this very deployed backend) are
# both always allowed — these aren't mutually exclusive by environment, so
# don't branch on settings.env here. Arbitrary third-party origins are
# still rejected either way.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://learning-application-1.onrender.com"],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(campaign_router)
app.include_router(health_router)
app.include_router(legal_router)
app.include_router(auth_router)
app.include_router(content_router)
app.include_router(content_public_router)
app.include_router(contributions_router)
app.include_router(game_router)
app.include_router(moderation_router)
app.include_router(moderation_admin_router)
app.include_router(profile_router)
app.include_router(quests_router)
app.include_router(social_router)
app.include_router(teacher_router)
app.include_router(classroom_router)
app.include_router(telemetry_router)


@app.get("/")
async def root() -> dict:
    return {"service": "islamic-learning-game", "status": "running"}


# Wrap FastAPI so Socket.IO owns "/socket.io/*" and delegates everything else
# (REST routes) to FastAPI. Run with:  uvicorn app.main:asgi_app --reload
import socketio  # noqa: E402

asgi_app = socketio.ASGIApp(sio, other_asgi_app=app)