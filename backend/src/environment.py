import pydantic_settings


class Environment(pydantic_settings.BaseSettings):
    port: int = 8080
    cors_origin: str = "http://localhost:5173"
