from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    database_url: str = "mysql+pymysql://root:12345678@127.0.0.1:3306/ai_chat?charset=utf8mb4"
    cors_origins: List[str] = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8081",
        "http://127.0.0.1:8081",
    ]

    class Config:
        env_file = None 
        env_prefix = ""
        case_sensitive = False


settings = Settings()

