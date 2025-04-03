#!/bin/bash

echo "Setting up Traefik as reverse proxy with NextJS, Directus, and Kong"

# Create Traefik network if it doesn't exist
if ! docker network ls | grep -q traefik_network; then
  echo "Creating Traefik network..."
  docker network create traefik_network
else
  echo "Traefik network already exists."
fi

# Start Traefik
echo "Starting Traefik..."
cd traefik
docker-compose up -d
cd ..

# Wait for Traefik to be ready
echo "Waiting for Traefik to initialize..."
sleep 5

# Start Directus
echo "Starting Directus..."
cd directus
docker-compose up -d
cd ..

# Start Kong
echo "Starting Kong API Gateway..."
cd kong
docker-compose up -d
cd ..

# Start Frontend
echo "Starting NextJS Frontend..."
cd frontend
docker-compose up -d --build
cd ..

echo "Waiting for services to be fully operational..."
sleep 10

echo "Setup complete! You can now access:"
echo "- Traefik Dashboard: http://localhost:8080"
echo "- NextJS Frontend: http://localhost/"
echo "- Directus via Traefik: http://localhost/dmc"
echo "- Directus Admin via Traefik: http://localhost/dmc/admin"
echo "- Kong API Gateway via Traefik: http://localhost/apigw"
echo "- Kong Admin API (direct): http://localhost:8001"
echo "- Kong Manager UI: http://localhost:8002"
