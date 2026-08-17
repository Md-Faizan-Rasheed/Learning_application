from fastapi import FastAPI

from .health.routes import router as health_router
from fastapi.middleware.cors import CORSMiddleware


app = FastAPI(title="Islamic Learning Game API")

origins = [
    "http://localhost.tiangolo.com",
    "https://localhost.tiangolo.com",
    "http://localhost",
    "http://localhost:8080",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)


@app.get("/")
async def root() -> dict:
    return {"service": "islamic-learning-game", "status": "running"}