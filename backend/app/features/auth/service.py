from fastapi import HTTPException, status
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests

from app.core.config import settings
from app.core.security import hash_password, verify_password, create_access_token
from app.features.auth.model import User, AuthProvider
from app.features.auth.repository import AuthRepository
from app.features.auth.schemas import RegisterRequest, LoginRequest, SocialAuthRequest, AuthResponse


class AuthService:
    def __init__(self, repo: AuthRepository):
        self.repo = repo

    async def register(self, data: RegisterRequest) -> AuthResponse:
        if await self.repo.get_by_email(data.email):
            raise HTTPException(status.HTTP_409_CONFLICT, "Bu email zaten kayıtlı")
        if await self.repo.username_exists(data.username):
            raise HTTPException(status.HTTP_409_CONFLICT, "Bu kullanıcı adı alınmış")

        user = User(
            email=data.email,
            username=data.username,
            password_hash=hash_password(data.password),
            auth_provider=AuthProvider.email,
        )
        user = await self.repo.create(user)
        token = create_access_token(user.id)
        return AuthResponse(access_token=token, user_id=user.id, username=user.username)

    async def login(self, data: LoginRequest) -> AuthResponse:
        user = await self.repo.get_by_email(data.email)
        if not user or not verify_password(data.password, user.password_hash or ""):
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Email veya şifre hatalı")

        token = create_access_token(user.id)
        return AuthResponse(access_token=token, user_id=user.id, username=user.username)

    async def social_auth(self, data: SocialAuthRequest) -> AuthResponse:
        if data.provider == AuthProvider.google:
            return await self._google_auth(data.token)
        elif data.provider == AuthProvider.apple:
            return await self._apple_auth(data.token)
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Geçersiz provider")

    async def _google_auth(self, token: str) -> AuthResponse:
        try:
            info = id_token.verify_oauth2_token(token, google_requests.Request(), settings.google_client_id)
        except Exception:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Geçersiz Google token")

        provider_id = info["sub"]
        email = info["email"]

        user = await self.repo.get_by_provider(provider_id)
        if not user:
            user = await self.repo.get_by_email(email)
        if not user:
            username = email.split("@")[0]
            if await self.repo.username_exists(username):
                username = f"{username}_{provider_id[:6]}"
            user = User(
                email=email,
                username=username,
                auth_provider=AuthProvider.google,
                provider_id=provider_id,
            )
            user = await self.repo.create(user)

        token = create_access_token(user.id)
        return AuthResponse(access_token=token, user_id=user.id, username=user.username)

    async def _apple_auth(self, token: str) -> AuthResponse:
        # Apple JWT doğrulama — Apple public key ile verify edilmeli
        # Şimdilik stub, ileride tamamlanacak
        raise HTTPException(status.HTTP_501_NOT_IMPLEMENTED, "Apple giriş yakında")
