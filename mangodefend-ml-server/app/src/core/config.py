import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # App Settings
    APP_NAME: str = "MangoDefend ML Server"
    DEBUG: bool = True

    # Database Settings
    DATABASE_URL: str = "postgresql://postgres:secretpassword@postgres:5432/mangodefend_database"

    # Redis Settings
    REDIS_URL: str = "redis://redis:6379/0"

    # RabbitMQ Settings
    RABBITMQ_URL: str = "amqp://guest:guest@rabbitmq:5672/"

    # Object Storage (S3 / Supabase / MinIO)
    S3_ENDPOINT_URL: str = ""
    S3_ACCESS_KEY_ID: str = ""
    S3_SECRET_ACCESS_KEY: str = ""
    S3_BUCKET_RAW: str = "raw-uploads"
    S3_BUCKET_QUARANTINE: str = "quarantine-files"
    S3_REGION: str = "us-east-1"

    # Security & JWT
    SECRET_KEY: str = "default_secret_key_please_change_in_production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    # Payment Gateway (Midtrans)
    MIDTRANS_SERVER_KEY: str = "your_server_key"
    MIDTRANS_CLIENT_KEY: str = "your_client_key"
    MIDTRANS_IS_PRODUCTION: bool = False
    MIDTRANS_MERCHANT_ID: str = ""

    model_config = SettingsConfigDict(
        env_file=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), ".env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
