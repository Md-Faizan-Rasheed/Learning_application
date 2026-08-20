from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .content.routes import router as content_router
from .game.routes import router as game_router
from .health.routes import router as health_router
from .auth.routes import router as auth_router
from .realtime.server import sio
from .progression.routes import router as profile_router

app = FastAPI(title="Islamic Learning Game API")

# CORS: browsers block cross-origin calls, so the Flutter web app (served
# from a localhost dev port) can't reach this API unless we allow it.
# In development we allow any localhost origin; production locks this down.
if settings.env == "development":
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(health_router)
app.include_router(content_router)
app.include_router(game_router)
app.include_router(auth_router)
app.include_router(profile_router)

@app.get("/")
async def root() -> dict:
    return {"service": "islamic-learning-game", "status": "running"}


# Wrap FastAPI so Socket.IO owns "/socket.io/*" and delegates everything else
# (REST routes) to FastAPI. Run with:  uvicorn app.main:asgi_app --reload
import socketio  # noqa: E402

asgi_app = socketio.ASGIApp(sio, other_asgi_app=app)