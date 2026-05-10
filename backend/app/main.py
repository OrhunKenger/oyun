from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.features.auth.router import router as auth_router
from app.features.resources.router import router as resources_router
from app.features.map.router import router as map_router
from app.features.battle.router import router as battle_router
from app.features.leaderboard.router import router as leaderboard_router

app = FastAPI(title=settings.app_name, debug=settings.debug)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(resources_router, prefix="/api/v1/resources", tags=["resources"])
app.include_router(map_router, prefix="/api/v1/map", tags=["map"])
app.include_router(battle_router, prefix="/api/v1/battle", tags=["battle"])
app.include_router(leaderboard_router, prefix="/api/v1/leaderboard", tags=["leaderboard"])


@app.get("/health")
async def health():
    return {"status": "ok"}
