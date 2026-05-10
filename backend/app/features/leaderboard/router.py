from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from pydantic import BaseModel

from app.core.database import get_db
from app.features.auth.router import get_current_user
from app.features.auth.model import User
from app.features.map.model import MapPixel
from sqlalchemy import func

router = APIRouter()


class LeaderboardEntry(BaseModel):
    rank: int
    user_id: str
    username: str
    pixel_count: int
    prestige: int
    total_score: int

    class Config:
        from_attributes = True


class LeaderboardResponse(BaseModel):
    entries: list[LeaderboardEntry]
    my_rank: int | None
    total_players: int


@router.get("/", response_model=LeaderboardResponse)
async def get_leaderboard(
    limit: int = Query(50, le=100),
    offset: int = Query(0),
    user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Piksel sayısına göre sırala
    pixel_counts = await db.execute(
        select(MapPixel.owner_id, func.count().label("pixel_count"))
        .where(MapPixel.owner_id.isnot(None))
        .group_by(MapPixel.owner_id)
        .order_by(desc("pixel_count"))
        .limit(limit)
        .offset(offset)
    )
    rows = pixel_counts.all()

    entries = []
    for rank, row in enumerate(rows, start=offset + 1):
        u = await db.get(User, row.owner_id)
        if u:
            entries.append(LeaderboardEntry(
                rank=rank,
                user_id=u.id,
                username=u.username,
                pixel_count=row.pixel_count,
                prestige=u.prestige,
                total_score=u.total_score,
            ))

    # Kendi sıramı bul
    my_rank_result = await db.execute(
        select(func.count()).select_from(
            select(MapPixel.owner_id, func.count().label("pc"))
            .where(MapPixel.owner_id.isnot(None))
            .group_by(MapPixel.owner_id)
            .having(func.count() > select(func.count())
                    .where(MapPixel.owner_id == user.id)
                    .scalar_subquery())
            .subquery()
        )
    )
    my_rank = (my_rank_result.scalar() or 0) + 1

    total_result = await db.execute(
        select(func.count(func.distinct(MapPixel.owner_id)))
    )
    total = total_result.scalar() or 0

    return LeaderboardResponse(entries=entries, my_rank=my_rank, total_players=total)
