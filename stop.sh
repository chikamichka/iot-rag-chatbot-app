#!/bin/bash

echo "🛑 Stopping IoT RAG Chatbot Services..."

# Stop Docker containers
docker-compose down

# Stop Ollama if running
if pgrep -x "ollama" > /dev/null; then
    echo "Stopping Ollama..."
    pkill ollama
fi

echo "✅ All services stopped!"