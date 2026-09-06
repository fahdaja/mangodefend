from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.src.core.config import settings

# Create SQLAlchemy engine
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    echo=settings.DEBUG
)

# Session factory for DB interactions
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Declarative Base for ORM Models
Base = declarative_base()


def get_db():
    """Dependency injection for FastAPI route handlers."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
