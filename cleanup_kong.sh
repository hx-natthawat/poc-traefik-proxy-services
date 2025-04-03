#!/bin/bash

echo "Stopping Kong services..."
cd kong
docker-compose down

echo "Kong services stopped."

# Ask if user wants to remove volumes
read -p "Do you want to remove Kong data volumes? (y/n): " remove_volumes
if [[ $remove_volumes == "y" || $remove_volumes == "Y" ]]; then
  docker volume rm kong_kong_data
  echo "Kong data volumes removed."
fi

echo "Kong cleanup complete."
