# Implementation Guide: Traefik Reverse Proxy with NextJS, Directus, and Kong

## Overview

This guide provides step-by-step instructions for setting up Traefik as a reverse proxy with Next.js as the frontend, Directus as the CMS backend, and Kong as the API Gateway. Traefik serves as the central reverse proxy that routes and manages requests to all services.

## Prerequisites

- Docker and Docker Compose installed
- Basic understanding of API gateways and RESTful services
- Git (for cloning repositories)

## Implementation Steps

### 1. Project Setup

```bash
# Create project directory structure
mkdir -p poc-proxy-directus/{traefik,directus}
cd poc-proxy-directus
```

### 2. Setting Up Directus

#### 2.1 Create Directus Docker Compose File

Create a `docker-compose.yml` file in the directus directory:

```bash
cd directus
```

Create `docker-compose.yml` with the following content:

```yaml
version: '3'

services:
  directus:
    image: directus/directus:latest
    # Not exposing port 8055 to prevent direct access
    # ports:
    #   - "8055:8055"
    environment:
      KEY: 'replace-with-random-key'
      SECRET: 'replace-with-random-secret'
      ADMIN_EMAIL: 'admin@example.com'
      ADMIN_PASSWORD: 'password123'
      DB_CLIENT: 'sqlite3'
      DB_FILENAME: '/directus/database/data.db'
      PUBLIC_URL: 'http://localhost/dmc'
    volumes:
      - ./database:/directus/database
      - ./uploads:/directus/uploads
    restart: unless-stopped
    networks:
      - directus_network
      - traefik_network
    labels:
      - "traefik.enable=true"
      # DMC API route
      - "traefik.http.routers.dmc-api.rule=PathPrefix(`/dmc/api`)"
      - "traefik.http.routers.dmc-api.service=directus"
      - "traefik.http.routers.dmc-api.middlewares=dmc-stripprefix"
      - "traefik.http.routers.dmc-api.priority=20"
      
      # DMC admin route
      - "traefik.http.routers.dmc-admin.rule=PathPrefix(`/dmc/admin`)"
      - "traefik.http.routers.dmc-admin.service=directus"
      - "traefik.http.routers.dmc-admin.middlewares=dmc-admin-stripprefix"
      - "traefik.http.routers.dmc-admin.priority=15"
      - "traefik.http.middlewares.dmc-admin-stripprefix.stripprefix.prefixes=/dmc"
      
      # DMC base path redirect
      - "traefik.http.routers.dmc-base.rule=Path(`/dmc`)"
      - "traefik.http.routers.dmc-base.middlewares=dmc-base-redirect"
      - "traefik.http.routers.dmc-base.priority=20"
      - "traefik.http.middlewares.dmc-base-redirect.redirectregex.regex=^/dmc$$"
      - "traefik.http.middlewares.dmc-base-redirect.redirectregex.replacement=/dmc/admin"
      - "traefik.http.middlewares.dmc-base-redirect.redirectregex.permanent=true"
      
      # DMC assets route
      - "traefik.http.routers.dmc-assets.rule=PathPrefix(`/dmc/admin/assets`)"
      - "traefik.http.routers.dmc-assets.service=directus"
      - "traefik.http.routers.dmc-assets.middlewares=dmc-stripprefix"
      - "traefik.http.routers.dmc-assets.priority=25"
      
      # Main DMC route
      - "traefik.http.routers.dmc.rule=PathPrefix(`/dmc`)"
      - "traefik.http.routers.dmc.service=directus"
      - "traefik.http.services.directus.loadbalancer.server.port=8055"
      - "traefik.http.middlewares.dmc-stripprefix.stripprefix.prefixes=/dmc"
      - "traefik.http.routers.dmc.middlewares=dmc-stripprefix"
      - "traefik.http.routers.dmc.priority=10"
      
      # Block direct access to admin
      - "traefik.http.routers.block-admin.rule=PathPrefix(`/admin`)"
      - "traefik.http.routers.block-admin.service=directus"
      - "traefik.http.routers.block-admin.middlewares=block-access"
      - "traefik.http.routers.block-admin.priority=100"
      
      # Block direct access to assets
      - "traefik.http.routers.block-assets.rule=PathPrefix(`/admin/assets`)"
      - "traefik.http.routers.block-assets.service=directus"
      - "traefik.http.routers.block-assets.middlewares=block-access"
      - "traefik.http.routers.block-assets.priority=100"
      
      # Middleware to block direct access using an impossible IP whitelist
      - "traefik.http.middlewares.block-access.ipwhitelist.sourcerange=255.255.255.255"

networks:
  directus_network:
    driver: bridge
  traefik_network:
    external: true
```

#### 2.2 Start Directus

```bash
docker-compose up -d
```

### 3. Setting Up Kong API Gateway

#### 3.1 Create Kong Docker Compose File

Navigate to the kong directory:

```bash
cd ../kong
```

Create `docker-compose.yml` with the following content:

```yaml
version: "3.8"

services:
  kong-db:
    image: postgres:16-alpine
    container_name: kong-db
    environment:
      - POSTGRES_USER=kong
      - POSTGRES_DB=kong
      - POSTGRES_PASSWORD=kongpass
    volumes:
      - kong_data:/var/lib/postgresql/data
    networks:
      - traefik_network
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "kong"]
      interval: 5s
      timeout: 5s
      retries: 5

  kong-migration:
    image: kong:latest
    container_name: kong-migration
    depends_on:
      - kong-db
    environment:
      - KONG_DATABASE=postgres
      - KONG_PG_HOST=kong-db
      - KONG_PG_USER=kong
      - KONG_PG_PASSWORD=kongpass
      - KONG_PG_DATABASE=kong
    command: kong migrations bootstrap
    networks:
      - traefik_network
    restart: on-failure

  kong:
    image: kong:latest
    container_name: kong
    depends_on:
      kong-db:
        condition: service_healthy
      kong-migration:
        condition: service_completed_successfully
    environment:
      - KONG_DATABASE=postgres
      - KONG_PG_HOST=kong-db
      - KONG_PG_USER=kong
      - KONG_PG_PASSWORD=kongpass
      - KONG_PG_DATABASE=kong
      - KONG_PROXY_ACCESS_LOG=/dev/stdout
      - KONG_ADMIN_ACCESS_LOG=/dev/stdout
      - KONG_PROXY_ERROR_LOG=/dev/stderr
      - KONG_ADMIN_ERROR_LOG=/dev/stderr
      - KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl
      - KONG_ADMIN_GUI_URL=http://localhost:8002/
      - KONG_ADMIN_GUI_LISTEN=0.0.0.0:8002, 0.0.0.0:8445 ssl
    ports:
      - "8000:8000"
      - "8001:8001"
      - "8002:8002"
      - "8443:8443"
      - "8444:8444"
    networks:
      - traefik_network
    labels:
      # Traefik integration
      - "traefik.enable=true"

      # API Gateway route
      - "traefik.http.routers.apigw.rule=PathPrefix(`/apigw`)"
      - "traefik.http.routers.apigw.service=kong"
      - "traefik.http.routers.apigw.middlewares=apigw-stripprefix"
      - "traefik.http.routers.apigw.priority=10"

      # Service definition
      - "traefik.http.services.kong.loadbalancer.server.port=8000"

      # Middleware for stripping prefix
      - "traefik.http.middlewares.apigw-stripprefix.stripprefix.prefixes=/apigw"

      # Kong Manager route
      - "traefik.http.routers.apigw-manager.rule=PathPrefix(`/apigw/manager`)"
      - "traefik.http.routers.apigw-manager.service=kong-manager"
      - "traefik.http.routers.apigw-manager.priority=20"

      # Kong Manager service definition
      - "traefik.http.services.kong-manager.loadbalancer.server.port=8002"

  # Kong Admin API is available at http://localhost:8001

volumes:
  kong_data:

networks:
  traefik_network:
    external: true
```

#### 3.2 Start Kong

```bash
docker-compose up -d
```

### 4. Setting Up Traefik Reverse Proxy

#### 4.1 Create Traefik Network

```bash
docker network create traefik_network
```

#### 4.2 Create Traefik Configuration

Navigate to the Traefik directory:

```bash
cd ../traefik
```

Create `docker-compose.yml` with the following content:

```yaml
version: '3'

services:
  traefik:
    image: traefik:v2.10
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--accesslog=true"
      - "--log.level=INFO"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./traefik.yml:/etc/traefik/traefik.yml:ro"
      - "./config:/etc/traefik/config"
    networks:
      - traefik_network
    restart: unless-stopped

networks:
  traefik_network:
    external: true
```

Create `traefik.yml` with the following content:

```yaml
api:
  insecure: true
  dashboard: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: "/etc/traefik/config"
    watch: true

log:
  level: "INFO"

accessLog: {}
```

Create a directory for dynamic configuration:

```bash
mkdir -p config
```

### 5. Setting Up NextJS Frontend

#### 5.1 Create NextJS Docker Compose File

Navigate to the frontend directory:

```bash
cd ../frontend
```

Create `Dockerfile` with the following content:

```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application
COPY . .

# Build the application
RUN npm run build

# Expose the port the app runs on
EXPOSE 3001

# Command to run the application
CMD ["node", "server.mjs"]
```

Create `docker-compose.yml` with the following content:

```yaml
version: '3'

services:
  frontend:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    networks:
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=PathPrefix(`/`)"
      - "traefik.http.routers.frontend.priority=1"
      - "traefik.http.services.frontend.loadbalancer.server.port=3001"

networks:
  traefik_network:
    external: true
```

Create a `.dockerignore` file with the following content:

```
node_modules
.next
.git
.github
.vscode
.env
.env.local
.env.development
.env.test
.env.production
```

Create `next.config.mjs` with the following content:

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  output: 'export',
  distDir: 'dist',
  images: {
    unoptimized: true
  }
};

export default nextConfig;
```

#### 5.2 Start NextJS Frontend

```bash
docker-compose up -d --build
```

### 6. Create Configuration Files

Create `config/directus.yml` with the following content:

```yaml
http:
  routers:
    # Main Directus API route
```

### 7. Creating Setup and Cleanup Scripts

#### 7.1 Create Setup Script

In the root directory, create a `setup_traefik.sh` script with the following content:

```bash
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
```

Make the script executable:

```bash
chmod +x setup_traefik.sh
```

#### 7.2 Create Cleanup Script

In the root directory, create a `cleanup_traefik.sh` script with the following content:

```bash
#!/bin/bash

echo "Cleaning up Traefik, Directus, Kong, and NextJS..."

# Stop and remove Frontend containers
echo "Stopping Frontend..."
cd frontend
docker-compose down
cd ..

# Stop and remove Kong containers
echo "Stopping Kong..."
cd kong
docker-compose down
cd ..

# Stop and remove Directus containers
echo "Stopping Directus..."
cd directus
docker-compose down
cd ..

# Stop and remove Traefik containers
echo "Stopping Traefik..."
cd traefik
docker-compose down
cd ..

# Ask if user wants to remove the network
read -p "Do you want to remove the Traefik network? (y/n): " remove_network
if [ "$remove_network" = "y" ]; then
  echo "Removing Traefik network..."
  docker network rm traefik_network
fi

# Ask if user wants to remove volumes
read -p "Do you want to remove all data volumes? This will delete all data! (y/n): " remove_volumes
if [ "$remove_volumes" = "y" ]; then
  echo "Removing volumes..."
  docker volume prune -f
fi

echo "Cleanup complete!"
```

Make the script executable:

```bash
chmod +x cleanup_traefik.sh
```

## Conclusion

You have now set up a complete system with Traefik as a reverse proxy routing to a Next.js frontend, Directus CMS, and Kong API Gateway. This architecture provides a unified entry point for all services while maintaining proper security and routing.

The key features of this setup are:

1. **Centralized Routing**: All requests go through Traefik, which routes them to the appropriate service.
2. **Path-Based Access**: Each service is accessible through a specific path prefix.
3. **Security**: Direct access to services is blocked, ensuring all traffic goes through the reverse proxy.
4. **Scalability**: Additional services can be easily added to the architecture by configuring Traefik.

For production use, consider adding SSL/TLS certificates, implementing more robust authentication, and replacing the placeholder credentials with secure values.
    directus-api:
      rule: "PathPrefix(`/directus/api`)"
      service: "directus"
      middlewares:
        - "directus-stripprefix"
      priority: 20

    # Directus admin route with /directus prefix
    directus-admin-prefixed:
      rule: "PathPrefix(`/directus/admin`)"
      service: "directus"
      middlewares:
        - "directus-stripprefix"
      priority: 15

    # Directus assets route with /directus prefix
    directus-assets-prefixed:
      rule: "PathPrefix(`/directus/admin/assets`)"
      service: "directus"
      middlewares:
        - "directus-stripprefix"
      priority: 25

    # Main Directus route for root access
    directus:
      rule: "PathPrefix(`/directus`)"
      service: "directus"
      middlewares:
        - "directus-stripprefix"
      priority: 10

    # DMC API route
    dmc-api:
      rule: "PathPrefix(`/dmc/api`)"
      service: "directus"
      middlewares:
        - "dmc-stripprefix"
      priority: 20

    # DMC admin route
    dmc-admin:
      rule: "PathPrefix(`/dmc/admin`)"
      service: "directus"
      middlewares:
        - "dmc-stripprefix"
      priority: 15

    # DMC assets route
    dmc-assets:
      rule: "PathPrefix(`/dmc/admin/assets`)"
      service: "directus"
      middlewares:
        - "dmc-stripprefix"
      priority: 25

    # Main DMC route
    dmc:
      rule: "PathPrefix(`/dmc`)"
      service: "directus"
      middlewares:
        - "dmc-stripprefix"
      priority: 10

    # Direct admin access (for compatibility)
    directus-admin:
      rule: "PathPrefix(`/admin`)"
      service: "directus"

    # Direct assets access (for compatibility)
    directus-assets:
      rule: "PathPrefix(`/admin/assets`)"
      service: "directus"
      priority: 10

  middlewares:
    directus-stripprefix:
      stripPrefix:
        prefixes:
          - "/directus"
    dmc-stripprefix:
      stripPrefix:
        prefixes:
          - "/dmc"

  services:
    directus:
      loadBalancer:
        servers:
          - url: "http://directus:8055"
```

#### 3.3 Start Traefik

```bash
docker-compose up -d
```

### 4. Testing the Setup

#### 4.1 Access Traefik Dashboard

Access the Traefik dashboard at `http://localhost:8080` to view and manage routes.

#### 4.2 Test Directus Routes

Test the Directus admin interface through Traefik:

```bash
curl -i http://localhost/dmc/admin
```

Test the Directus API through Traefik:

```bash
curl -i http://localhost/dmc/server/info
```

Test direct access to the admin interface (for compatibility):

```bash
curl -i http://localhost/admin
```

### 7. Troubleshooting

#### 7.1 Check Traefik Status

Check if Traefik is running:

```bash
docker ps | grep traefik
```

Check Traefik logs:

```bash
docker logs traefik-traefik-1
```

#### 7.2 Check Directus Status

Check if Directus is running:

```bash
docker ps | grep directus
```

Check Directus logs:

```bash
docker logs directus-directus-1
```

#### 7.3 Common Issues

- **Traefik can't connect to Directus**: Ensure both services are on the same Docker network
- **404 Not Found errors**: Check that the path prefixes in your Traefik rules match the requested URLs
- **Routing issues**: Verify that routes are correctly set up with proper paths and priorities
- **Redirect loops**: Make sure the `stripprefix` middleware is correctly configured

### 8. Automation Scripts

This project includes automation scripts to simplify setup and cleanup:

#### 8.1 Setup Script

The `setup_traefik.sh` script automates the process of setting up Traefik and Directus:

```bash
./setup_traefik.sh
```

This script:
1. Creates the Traefik network if it doesn't exist
2. Starts Traefik
3. Starts Directus with Traefik labels for routing

#### 8.2 Cleanup Script

The `cleanup_traefik.sh` script helps clean up the environment.

1. Stop Directus containers
2. Stop Traefik containers
3. Optionally remove the Traefik network
4. Optionally remove data volumes

### 9. Access Points

After setup, you can access the following endpoints:

#### 9.1 Directus Endpoints

- Directus Admin via Traefik: `http://localhost/dmc/admin`
- Directus API via Traefik: `http://localhost/dmc/server/info`

**Note**: Direct access to Directus is blocked. All access must go through the `/dmc` path.

#### 9.2 Kong API Gateway Endpoints

- Kong API Gateway via Traefik: `http://localhost/apigw`
- Kong Admin API (direct): `http://localhost:8001`
- Konga Admin UI via Traefik: `http://localhost/apigw/admin`

**Note**: Kong is configured to be accessible through the `/apigw` path when accessed via Traefik.

### 5. Testing the Setup

#### 5.1 Access Directus Through Traefik

Access Directus admin panel at `http://localhost/dmc/admin`

#### 5.2 Test API Access Through Traefik

Test the API gateway routing:

```bash
curl -i http://localhost/dmc/server/info
```

#### 5.3 Verify Direct Access Blocking

Verify that direct access to Directus is blocked:

```bash
curl -I http://localhost/admin
# Should return 403 Forbidden
```

This should route to the Directus API.

### 6. Advanced Configuration

#### 6.1 Adding Authentication with Kong

Create a consumer:

```bash
curl -i -X POST http://localhost:8001/consumers \
  --data username=api-consumer
```

Generate a key for the consumer:

```bash
curl -i -X POST http://localhost:8001/consumers/api-consumer/key-auth \
  --data key=your-api-key
```

Enable key authentication for the service:

```bash
curl -i -X POST http://localhost:8001/services/directus-service/plugins \
  --data name=key-auth
```

#### 6.2 Rate Limiting

Add rate limiting to protect your API:

```bash
curl -i -X POST http://localhost:8001/services/directus-service/plugins \
  --data name=rate-limiting \
  --data config.minute=100 \
  --data config.hour=1000
```

#### 6.3 Request Transformation

Add request transformation if needed:

```bash
curl -i -X POST http://localhost:8001/services/directus-service/plugins \
  --data name=request-transformer \
  --data config.add.headers[]=x-api-version:1.0
```

## Troubleshooting

### Common Issues

1. **Network Connectivity**: Ensure that both Kong and Directus containers can communicate with each other.

   - Check that both services are on the same Docker network.
   - Verify network settings with `docker network inspect kong_network`.

2. **Service Discovery**: If Kong cannot reach Directus, check the service URL.

   - Within Docker networks, use the service name as hostname (e.g., `http://directus:8055`).

3. **Configuration Errors**: Validate Kong configuration.
   - Check Kong logs: `docker logs kong_kong_1`
   - Verify routes and services: `curl http://localhost:8001/services` and `curl http://localhost:8001/routes`

## Conclusion

You now have a working setup with Kong API Gateway routing requests to a Directus backend. This architecture provides benefits such as:

- Centralized API management
- Enhanced security through Kong plugins
- Traffic control and monitoring
- Ability to add more backend services behind the same gateway

For production deployments, consider additional security measures, proper secret management, and infrastructure redundancy.
