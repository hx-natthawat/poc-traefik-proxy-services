#!/bin/bash

echo "Stopping and cleaning up Traefik, NextJS, and Directus services..."

# Stop Frontend
echo "Stopping NextJS Frontend..."
cd frontend
docker-compose down
cd ..

# Stop Directus
echo "Stopping Directus..."
cd directus
docker-compose down
cd ..

# Stop Traefik
echo "Stopping Traefik..."
cd traefik
docker-compose down
cd ..

# Ask if the user wants to remove the Docker network
read -p "Do you want to remove the Traefik network? (y/n): " remove_network
if [[ $remove_network == "y" || $remove_network == "Y" ]]; then
  echo "Removing Traefik network..."
  docker network rm traefik-public
fi

# Ask if the user wants to remove volumes (data)
read -p "Do you want to remove all data (volumes)? This will delete all Directus data. (y/n): " remove_data
if [[ $remove_data == "y" || $remove_data == "Y" ]]; then
  echo "Removing data volumes..."
  rm -rf directus/database
  rm -rf directus/uploads
  echo "Data volumes removed."
fi

echo "Cleanup complete!"
