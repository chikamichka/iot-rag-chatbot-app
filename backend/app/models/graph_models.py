from typing import List, Optional
from pydantic import BaseModel

class IoTConcept(BaseModel):
    """Represents an IoT concept node"""
    id: str
    name: str
    type: str  # protocol, technology, use_case, security_practice, etc.
    description: Optional[str] = None
    properties: Optional[dict] = None

class Relationship(BaseModel):
    """Represents a relationship between concepts"""
    source_id: str
    target_id: str
    relationship_type: str  # uses, implements, secures, enables, etc.
    properties: Optional[dict] = None