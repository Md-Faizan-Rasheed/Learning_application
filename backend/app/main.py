from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .content.routes import router as content_router
from .health.routes import router as health_router
from .game.routes import router as game_router

app = FastAPI(title="Islamic Learning Game API")

# CORS: browsers block cross-origin calls, so the Flutter web app (served
# from a localhost dev port) can't reach this API unless we allow it.
# In development we allow any localhost origin; production locks this down.
if settings.env == "development":
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(health_router)
app.include_router(content_router)
app.include_router(game_router)



@app.get("/")
async def root() -> dict:
    return {"service": "islamic-learning-game", "status": "running"}