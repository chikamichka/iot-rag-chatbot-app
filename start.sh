#!/bin/bash

echo "🚀 Starting IoT RAG Chatbot Services..."
echo ""

# Check if Ollama is running locally
if ! pgrep -x "ollama" > /dev/null; then
    echo "🤖 Starting Ollama locally..."
    ollama serve > /tmp/ollama.log 2>&1 &
    sleep 3
fi

# Check if Llama2 model exists
echo "📦 Checking Llama2 model..."
if ! ollama list | grep -q "llama2"; then
    echo "⬇️  Pulling Llama2 model (this may take a while)..."
    ollama pull llama2
fi

echo "🐳 Building and starting Docker containers..."
docker-compose up -d --build

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
echo ""

# Wait for Neo4j
echo -n "   Waiting for Neo4j..."
for i in {1..30}; do
    if docker exec iot-neo4j cypher-shell -u neo4j -p iot-password-2024 "RETURN 1" > /dev/null 2>&1; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 2
done

# Wait for Backend
echo -n "   Waiting for Backend..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo "✅ All services are running!"
echo ""
echo "🌐 Access points:"
echo "   - Backend API: http://localhost:8000"
echo "   - API Docs: http://localhost:8000/docs"
echo "   - Neo4j Browser: http://localhost:7474"
echo "   - Ollama: http://localhost:11434"
echo ""
echo "📊 View logs: docker-compose logs -f backend"
echo "🛑 To stop: docker-compose down"
echo "🔄 To restart: docker-compose restart"
echo ""
echo "📱 Mobile App: Update API URL to your Mac's IP address"
echo "   Find your IP: ifconfig | grep 'inet ' | grep -v 127.0.0.1"