from neo4j import GraphDatabase
from app.core.config import settings
from app.models.graph_models import IoTConcept, Relationship
from typing import List, Dict, Any
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class GraphService:
    def __init__(self):
        self.driver = None
        
    def connect(self):
        """Connect to Neo4j database"""
        try:
            self.driver = GraphDatabase.driver(
                settings.NEO4J_URI,
                auth=(settings.NEO4J_USER, settings.NEO4J_PASSWORD)
            )
            logger.info("✅ Connected to Neo4j successfully")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to connect to Neo4j: {e}")
            return False
    
    def close(self):
        """Close Neo4j connection"""
        if self.driver:
            self.driver.close()
            logger.info("Neo4j connection closed")
    
    def test_connection(self):
        """Test the connection with a simple query"""
        try:
            with self.driver.session() as session:
                result = session.run("RETURN 'Connection successful!' as message")
                record = result.single()
                logger.info(f"✅ Neo4j test: {record['message']}")
                return True
        except Exception as e:
            logger.error(f"❌ Neo4j test failed: {e}")
            return False
    
    def create_concept(self, concept: IoTConcept) -> bool:
        """Create an IoT concept node in the graph"""
        try:
            with self.driver.session() as session:
                query = """
                MERGE (c:Concept {id: $id})
                SET c.name = $name,
                    c.type = $type,
                    c.description = $description
                RETURN c
                """
                session.run(
                    query,
                    id=concept.id,
                    name=concept.name,
                    type=concept.type,
                    description=concept.description
                )
                logger.info(f"✅ Created concept: {concept.name}")
                return True
        except Exception as e:
            logger.error(f"❌ Failed to create concept: {e}")
            return False
    
    def create_relationship(self, rel: Relationship) -> bool:
        """Create a relationship between concepts"""
        try:
            with self.driver.session() as session:
                query = f"""
                MATCH (source:Concept {{id: $source_id}})
                MATCH (target:Concept {{id: $target_id}})
                MERGE (source)-[r:{rel.relationship_type}]->(target)
                RETURN r
                """
                session.run(
                    query,
                    source_id=rel.source_id,
                    target_id=rel.target_id
                )
                logger.info(f"✅ Created relationship: {rel.source_id} -{rel.relationship_type}-> {rel.target_id}")
                return True
        except Exception as e:
            logger.error(f"❌ Failed to create relationship: {e}")
            return False
    
    def get_related_concepts(self, concept_id: str, max_depth: int = 2) -> List[Dict[str, Any]]:
        """Get concepts related to a given concept"""
        try:
            with self.driver.session() as session:
                query = """
                MATCH path = (c:Concept {id: $concept_id})-[*1..2]-(related:Concept)
                RETURN DISTINCT related.id as id, 
                       related.name as name, 
                       related.type as type,
                       related.description as description
                LIMIT 20
                """
                result = session.run(query, concept_id=concept_id)
                concepts = [dict(record) for record in result]
                return concepts
        except Exception as e:
            logger.error(f"❌ Failed to get related concepts: {e}")
            return []
    
    def initialize_sample_graph(self):
        """Initialize graph with sample IoT concepts and relationships"""
        try:
            logger.info("🔨 Initializing sample IoT knowledge graph...")
            
            # Create concepts
            concepts = [
                IoTConcept(id="mqtt", name="MQTT", type="protocol", 
                          description="Lightweight publish-subscribe protocol for IoT"),
                IoTConcept(id="coap", name="CoAP", type="protocol",
                          description="Constrained Application Protocol for resource-limited devices"),
                IoTConcept(id="http", name="HTTP/HTTPS", type="protocol",
                          description="Traditional web protocols adapted for IoT"),
                IoTConcept(id="lorawan", name="LoRaWAN", type="protocol",
                          description="Long-range, low-power protocol for IoT networks"),
                IoTConcept(id="edge_computing", name="Edge Computing", type="technology",
                          description="Processing data near the source rather than in cloud"),
                IoTConcept(id="smart_home", name="Smart Home", type="use_case",
                          description="Home automation using IoT devices"),
                IoTConcept(id="iiot", name="Industrial IoT", type="use_case",
                          description="IoT applications in manufacturing and industry"),
                IoTConcept(id="encryption", name="Encryption", type="security_practice",
                          description="Encrypted communication channels for IoT"),
                IoTConcept(id="authentication", name="Authentication", type="security_practice",
                          description="Device authentication and authorization"),
            ]
            
            for concept in concepts:
                self.create_concept(concept)
            
            # Create relationships
            relationships = [
                Relationship(source_id="mqtt", target_id="smart_home", relationship_type="USED_IN"),
                Relationship(source_id="coap", target_id="edge_computing", relationship_type="ENABLES"),
                Relationship(source_id="lorawan", target_id="iiot", relationship_type="USED_IN"),
                Relationship(source_id="encryption", target_id="mqtt", relationship_type="SECURES"),
                Relationship(source_id="authentication", target_id="mqtt", relationship_type="SECURES"),
                Relationship(source_id="edge_computing", target_id="iiot", relationship_type="ENABLES"),
                Relationship(source_id="http", target_id="smart_home", relationship_type="USED_IN"),
            ]
            
            for rel in relationships:
                self.create_relationship(rel)
            
            logger.info("✅ Sample IoT knowledge graph initialized")
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to initialize graph: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False

# Create singleton instance
graph_service = GraphService()