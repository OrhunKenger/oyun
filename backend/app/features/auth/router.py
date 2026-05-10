from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import decode_token
from app.features.auth.repository import AuthRepository
from app.features.auth.service import AuthService
from app.features.auth.schemas import RegisterRequest, LoginRequest, SocialAuthRequest, AuthResponse, UserProfile
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

router = APIRouter()
bearer = HTTPBearer()


def get_service(db: AsyncSession = Depends(get_db)) -> AuthService:
    return AuthService(AuthRepository(db))


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: AsyncSession = Depends(get_db),
):
    user_id = decode_token(credentials.credentials)
    if not user_id:
        from fastapi import HTTPException, status
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Geçersiz token")
    repo = AuthRepository(db)
    user = await repo.get_by_id(user_id)
    if not user:
        from fastapi import HTTPException, status
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Kullanıcı bulunamadı")
    return user


@router.post("/register", response_model=AuthResponse)
async def register(data: RegisterRequest, service: AuthService = Depends(get_service)):
    return await service.register(data)


@router.post("/login", response_model=AuthResponse)
async def login(data: LoginRequest, service: AuthService = Depends(get_service)):
    return await service.login(data)


@router.post("/social", response_model=AuthResponse)
async def social_auth(data: SocialAuthRequest, service: AuthService = Depends(get_service)):
    return await service.social_auth(data)


@router.get("/me", response_model=UserProfile)
async def me(user=Depends(get_current_user)):
    return user
