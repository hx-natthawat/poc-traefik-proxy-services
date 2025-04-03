# Implementation Guide: Traefik Reverse Proxy with DMC Backend

## Overview

This guide provides step-by-step instructions for setting up Traefik as a reverse proxy with Directus as a backend service. Traefik will serve as the reverse proxy that routes and manages requests to the Directus headless CMS.

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
version: "3"

services:
  directus:
    image: directus/directus:latest
    ports:
      - "8055:8055"
    environment:
      KEY: "replace-with-random-key"
      SECRET: "replace-with-random-secret"
      ADMIN_EMAIL: "admin@example.com"
      ADMIN_PASSWORD: "password123"
      DB_CLIENT: "sqlite3"
      DB_FILENAME: "/directus/database/data.db"
    volumes:
      - ./database:/directus/database
      - ./uploads:/directus/uploads
    restart: unless-stopped
    networks:
      - directus_network
      - traefik_network
    labels:
      - "traefik.enable=true"
      # Main API route
      - "traefik.http.routers.directus-api.rule=PathPrefix(`/directus/api`)"
      - "traefik.http.routers.directus-api.service=directus"
      - "traefik.http.routers.directus-api.middlewares=directus-stripprefix"
      - "traefik.http.routers.directus-api.priority=20"
      
      # Admin route with /directus prefix
      - "traefik.http.routers.directus-admin-prefixed.rule=PathPrefix(`/directus/admin`)"
      - "traefik.http.routers.directus-admin-prefixed.service=directus"
      - "traefik.http.routers.directus-admin-prefixed.middlewares=directus-stripprefix"
      - "traefik.http.routers.directus-admin-prefixed.priority=15"
      
      # Assets route with /directus prefix
      - "traefik.http.routers.directus-assets-prefixed.rule=PathPrefix(`/directus/admin/assets`)"
      - "traefik.http.routers.directus-assets-prefixed.service=directus"
      - "traefik.http.routers.directus-assets-prefixed.middlewares=directus-stripprefix"
      - "traefik.http.routers.directus-assets-prefixed.priority=25"
      
      # Main Directus route
      - "traefik.http.routers.directus.rule=PathPrefix(`/directus`)"
      - "traefik.http.routers.directus.service=directus"
      - "traefik.http.services.directus.loadbalancer.server.port=8055"
      - "traefik.http.middlewares.directus-stripprefix.stripprefix.prefixes=/directus"
      - "traefik.http.routers.directus.middlewares=directus-stripprefix"
      - "traefik.http.routers.directus.priority=10"
      
      # DMC routes
      - "traefik.http.routers.dmc.rule=PathPrefix(`/dmc`)"
      - "traefik.http.routers.dmc.service=directus"
      - "traefik.http.middlewares.dmc-stripprefix.stripprefix.prefixes=/dmc"
      - "traefik.http.routers.dmc.middlewares=dmc-stripprefix"
      - "traefik.http.routers.dmc.priority=10"
      
      # Direct admin access (for compatibility)
      - "traefik.http.routers.directus-admin.rule=PathPrefix(`/admin`)"
      - "traefik.http.routers.directus-admin.service=directus"
      
      # Direct assets access (for compatibility)
      - "traefik.http.routers.directus-assets.rule=PathPrefix(`/admin/assets`)"
      - "traefik.http.routers.directus-assets.service=directus"
      - "traefik.http.routers.directus-assets.priority=10"

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

### 3. Setting Up Traefik Reverse Proxy

#### 3.1 Create Traefik Network

```bash
docker network create traefik_network
```

#### 3.2 Create Traefik Configuration

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

Create `config/directus.yml` with the following content:

```yaml
http:
  routers:
    # Main Directus API route
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
