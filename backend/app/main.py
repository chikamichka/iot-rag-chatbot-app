from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.services.graph_service import graph_service
from app.services.rag_service import rag_service
from app.api.routes import router as api_router
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("🚀 Starting up application...")
    
    # Initialize Graph DB
    graph_service.connect()
    graph_service.test_connection()
    graph_service.initialize_sample_graph()  # Add this line
    
    # Initialize RAG Service
    rag_service.initialize()
    rag_service.load_documents()
    
    yield
    
    # Shutdown
    logger.info("🛑 Shutting down application...")
    graph_service.close()

app = FastAPI(
    title="IoT RAG Chatbot API",
    description="RAG-powered chatbot with Graph Knowledge Base",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(api_router)

@app.get("/")
async def root():
    return {
        "message": "IoT RAG Chatbot API",
        "status": "running",
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}