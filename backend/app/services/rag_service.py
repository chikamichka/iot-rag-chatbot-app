from llama_index import (
    VectorStoreIndex,
    SimpleDirectoryReader,
    ServiceContext,
    StorageContext
)
from llama_index.llms import Ollama
from llama_index.vector_stores import ChromaVectorStore
from llama_index.embeddings import HuggingFaceEmbedding
import chromadb
from pathlib import Path
import logging
import os
from app.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RAGService:
    def __init__(self):
        self.index = None
        self.query_engine = None
        self.embed_model = None
        self.chroma_client = None
        self.collection = None
        self.llm = None
        
    def initialize(self):
        """Initialize the RAG service with ChromaDB and embeddings"""
        try:
            logger.info("🔧 Initializing RAG Service...")
            
            # Get Ollama host from environment or use default
            ollama_host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
            
            # Initialize LLM (Ollama with Llama2)
            logger.info(f"🤖 Initializing Llama2 LLM at {ollama_host}...")
            self.llm = Ollama(
                model="llama2",
                request_timeout=120.0,
                temperature=0.7,
                base_url=ollama_host
            )
            
            # Initialize embedding model (using local model, no API key needed)
            logger.info("📦 Loading embedding model...")
            self.embed_model = HuggingFaceEmbedding(
                model_name="sentence-transformers/all-MiniLM-L6-v2"
            )
            
            # Initialize ChromaDB
            logger.info("🗄️ Initializing ChromaDB...")
            self.chroma_client = chromadb.PersistentClient(
                path=settings.CHROMA_PERSIST_DIR
            )
            
            # Create or get collection
            self.collection = self.chroma_client.get_or_create_collection(
                name="iot_documents"
            )
            
            logger.info("✅ RAG Service initialized successfully")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to initialize RAG Service: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False
    
    def load_documents(self, docs_path: str = "app/data/docs"):
        """Load documents from directory"""
        try:
            logger.info(f"📚 Loading documents from {docs_path}...")
            
            # Check if directory exists and has files
            docs_dir = Path(docs_path)
            if not docs_dir.exists():
                logger.error(f"❌ Directory {docs_path} does not exist")
                return False
            
            files = list(docs_dir.glob("*.txt"))
            if not files:
                logger.warning(f"⚠️ No .txt files found in {docs_path}")
                return False
            
            logger.info(f"📄 Found {len(files)} document(s)")
            
            # Load documents
            documents = SimpleDirectoryReader(docs_path).load_data()
            logger.info(f"✅ Loaded {len(documents)} document(s)")
            
            # Create vector store
            vector_store = ChromaVectorStore(chroma_collection=self.collection)
            storage_context = StorageContext.from_defaults(vector_store=vector_store)
            
            # Create service context with embedding model and LLM
            service_context = ServiceContext.from_defaults(
                embed_model=self.embed_model,
                llm=self.llm
            )
            
            # Create index
            logger.info("🔨 Building vector index...")
            self.index = VectorStoreIndex.from_documents(
                documents,
                storage_context=storage_context,
                service_context=service_context,
                show_progress=True
            )
            
            # Create query engine with custom prompt
            self.query_engine = self.index.as_query_engine(
                similarity_top_k=3,
                response_mode="compact"
            )
            
            logger.info("✅ Documents loaded and indexed successfully")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to load documents: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False

    def search(self, query: str, conversation_history: list = None, top_k: int = 3):
        """Search for relevant documents and generate answer with conversation context"""
        try:
            if not self.query_engine:
                logger.error("❌ Query engine not initialized")
                return None
            
            logger.info(f"🔍 Searching for: {query}")
            
            # Build context-aware query if we have conversation history
            if conversation_history and len(conversation_history) > 0:
                # Get last few exchanges for context
                recent_history = conversation_history[-4:] if len(conversation_history) > 4 else conversation_history
                context = "\n".join([
                    f"{'User' if msg['isUser'] else 'Assistant'}: {msg['content'][:200]}"
                    for msg in recent_history
                ])
                
                # Enhance query with context
                enhanced_query = f"Given this conversation context:\n{context}\n\nNow answer: {query}"
                logger.info(f"📝 Enhanced query with conversation context")
            else:
                enhanced_query = query
            
            response = self.query_engine.query(enhanced_query)
            
            return {
                "response": str(response),
                "source_nodes": [
                    {
                        "text": node.node.text[:200] + "..." if len(node.node.text) > 200 else node.node.text,
                        "score": node.score
                    }
                    for node in response.source_nodes
                ]
            }
            
        except Exception as e:
            logger.error(f"❌ Search failed: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return None


# Create singleton instance
rag_service = RAGService()
