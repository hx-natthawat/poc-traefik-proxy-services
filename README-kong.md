# Kong API Gateway Configuration

## Overview

This project includes Kong API Gateway configured with Traefik as a reverse proxy. The following endpoints are available:

- Kong API Gateway: `http://localhost/apigw`
- Kong Admin API: `http://localhost/apigw/admin`
- Kong Manager UI: `http://localhost:8002`

## Important Notes

### Kong Manager UI Access

Due to limitations in how the Kong Manager UI handles base paths, the Kong Manager UI is **not** accessible through the Traefik proxy path (`/apigw/manager`). Instead, you must access it directly at:

```
http://localhost:8002
```

### Kong Admin API

The Kong Admin API is accessible through Traefik at:

```
http://localhost/apigw/admin
```

This allows you to manage Kong services, routes, plugins, and other configurations programmatically.

### Kong Proxy

The Kong Proxy, which handles API traffic, is accessible through Traefik at:

```
http://localhost/apigw
```

## Configuration Details

### Traefik Configuration

Traefik is configured to route requests to Kong services using the following paths:

- `/apigw` → Kong Proxy (port 8000)
- `/apigw/admin` → Kong Admin API (port 8001)

The configuration uses middleware to strip prefixes from requests before forwarding them to Kong.

### Kong Configuration

Kong is configured with the following environment variables:

- `KONG_ADMIN_LISTEN`: 0.0.0.0:8001, 0.0.0.0:8444 ssl
- `KONG_ADMIN_GUI_URL`: http://localhost:8002/
- `KONG_ADMIN_GUI_LISTEN`: 0.0.0.0:8002, 0.0.0.0:8445 ssl

## Troubleshooting

If you encounter issues accessing the Kong services, check the following:

1. Ensure that both Kong and Traefik containers are running
2. Check the Traefik logs for any routing errors
3. Verify that the Kong services are accessible directly (without Traefik)
4. For the Kong Manager UI, remember to access it directly at `http://localhost:8002`
