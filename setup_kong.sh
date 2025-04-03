#!/bin/bash

# Create the network if it doesn't exist
docker network inspect traefik_network >/dev/null 2>&1 || docker network create traefik_network

# Start Kong and related services
cd kong
docker-compose up -d

echo "Kong API Gateway is now running!"
echo "Access Kong Admin API at: http://localhost:8001"
echo "Access Kong Gateway via Traefik at: http://localhost/apigw"
