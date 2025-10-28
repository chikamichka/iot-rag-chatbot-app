from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Neo4j Configuration
    NEO4J_URI: str
    NEO4J_USER: str
    NEO4J_PASSWORD: str
    
    # API Configuration
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    
    # LLM Configuration
    OPENAI_API_KEY: Optional[str] = None
    OLLAMA_HOST: str = "http://localhost:11434"
    
    # Vector Store
    CHROMA_PERSIST_DIR: str = "./chroma_db"
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "allow"  # Allow extra fields from environment

settings = Settings()