# POC Proxy DMC

Proof of concept for using Traefik as a reverse proxy for NextJS, Directus CMS, and Kong API Gateway.

## Project Structure

```bash
poc-proxy-dmc/
├── directus/
│   └── docker-compose.yml
├── frontend/
│   ├── src/
│   ├── public/
│   ├── Dockerfile
│   └── docker-compose.yml
├── kong/
│   └── docker-compose.yml
├── traefik/
│   ├── config/
│   │   ├── directus.yml
│   │   ├── frontend.yml
│   │   └── kong.yml
│   ├── docker-compose.yml
│   └── traefik.yml
├── docker-compose.yml
├── setup_traefik.sh
├── cleanup_traefik.sh
├── setup_kong.sh
├── cleanup_kong.sh
├── instruction.md
└── README.md
```

## Setup Instructions

1. **Clone the Repository**:
   - Clone this repository to your local machine

2. Make the setup script executable:

```bash
chmod +x setup_traefik.sh
```

1. Run the setup scripts:

```bash
# Start Traefik and Directus
./setup_traefik.sh

# Start Kong API Gateway
./setup_kong.sh
```

This script will:

- Create the necessary Docker network
- Start Traefik
- Start Directus with Traefik labels for routing

### Cleanup

1. Make the cleanup script executable:

```bash
chmod +x cleanup_traefik.sh
```

1. Run the cleanup scripts:

```bash
# Clean up Traefik and Directus
./cleanup_traefik.sh

# Clean up Kong API Gateway
./cleanup_kong.sh
```

These scripts will:

- Stop all services
- Optionally remove the Docker network
- Optionally remove all data volumes

## Access Points

### Traefik

- Dashboard: `http://localhost:8080`

### NextJS Frontend

- Frontend: `http://localhost/`
- Architecture Diagram: `http://localhost/architecture`

### Directus
- Directus via Traefik: `http://localhost/dmc`
- Directus Admin via Traefik: `http://localhost/dmc/admin`

**Important**: Direct access to Directus is blocked for security reasons. All access must go through the `/dmc` path.

### Kong API Gateway

- Kong API Gateway via Traefik: `http://localhost/apigw`
- Kong Admin API via Traefik: `http://localhost/apigw/admin`
- Kong Manager UI (direct): `http://localhost:8002`

## Detailed Documentation

For detailed implementation steps and advanced configuration options, see [instruction.md](instruction.md).

## Testing the Setup

To test if Traefik is properly routing to Directus, run:

```bash
curl -i http://localhost/dmc/server/info
```

This should route to the Directus API.

## Notes

- Default Directus admin credentials: admin@example.com / password123
- For production use, replace the placeholder keys and passwords with secure values
- Traefik dashboard is available at `http://localhost:8080` for monitoring routes and services
- Any attempt to access Directus directly (without the `/dmc` path) will be blocked with a 403 Forbidden error
