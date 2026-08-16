from fastapi import FastAPI

from .health.routes import router as health_router

app = FastAPI(title="Islamic Learning Game API")
app.include_router(health_router)


@app.get("/")
async def root() -> dict:
    return {"service": "islamic-learning-game", "status": "running"}