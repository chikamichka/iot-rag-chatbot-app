from fastapi import APIRouter, HTTPException, UploadFile, File
from pydantic import BaseModel
from app.services.rag_service import rag_service
from app.services.graph_service import graph_service
from typing import List, Optional
import shutil
from pathlib import Path

router = APIRouter(prefix="/api/v1", tags=["chatbot"])

class QueryRequest(BaseModel):
    query: str
    top_k: Optional[int] = 3
    conversation_history: Optional[List[dict]] = None  # Added to support conversation context

class QueryResponse(BaseModel):
    query: str
    response: str
    sources: List[dict]

@router.post("/query", response_model=QueryResponse)
async def query_documents(request: QueryRequest):
    """Query the RAG system with conversation context"""
    try:
        result = rag_service.search(
            request.query,
            conversation_history=request.conversation_history,
            top_k=request.top_k
        )
        
        if not result:
            raise HTTPException(status_code=500, detail="Search failed")
        
        return QueryResponse(
            query=request.query,
            response=result["response"],
            sources=result["source_nodes"]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/upload")
async def upload_document(file: UploadFile = File(...)):
    """Upload a document to the knowledge base"""
    try:
        # Validate file type
        if not file.filename.endswith(('.txt', '.pdf', '.md')):
            raise HTTPException(
                status_code=400,
                detail="Only .txt, .pdf, and .md files are supported"
            )
        
        # Save file
        upload_dir = Path("app/data/docs")
        upload_dir.mkdir(parents=True, exist_ok=True)
        
        file_path = upload_dir / file.filename
        
        with file_path.open("wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Reload documents
        rag_service.load_documents()
        
        return {
            "status": "success",
            "filename": file.filename,
            "message": "Document uploaded and indexed successfully"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

class GraphQueryRequest(BaseModel):
    concept_id: str
    max_depth: Optional[int] = 2

@router.post("/graph/related")
async def get_related_concepts(request: GraphQueryRequest):
    """Get concepts related to a given concept from the knowledge graph"""
    try:
        concepts = graph_service.get_related_concepts(
            request.concept_id, 
            max_depth=request.max_depth
        )
        
        return {
            "concept_id": request.concept_id,
            "related_concepts": concepts,
            "count": len(concepts)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/health")
async def health():
    """Check if services are ready"""
    is_rag_ready = rag_service.query_engine is not None
    is_graph_ready = graph_service.driver is not None
    
    return {
        "status": "ready" if (is_rag_ready and is_graph_ready) else "not_ready",
        "rag_initialized": is_rag_ready,
        "graph_initialized": is_graph_ready
    }
