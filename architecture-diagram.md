# Project Architecture Diagram

```mermaid
graph TD
    Client[Client] --> Traefik[Traefik Proxy]
    
    Traefik -->|/| NextJS[NextJS Frontend]
    Traefik -->|/dmc| Directus[Directus CMS]
    Traefik -->|/apigw| Kong[Kong API Gateway]
    Traefik -->|/apigw/admin| KongAdmin[Kong Admin API]
    Client -->|Direct access port 8002| KongManager[Kong Manager UI]
    
    NextJS -.->|API Calls| Kong
    NextJS -.->|Content| Directus
    
    Directus --> DirectusDB[(Directus DB)]
    Kong --> KongDB[(Kong PostgreSQL DB)]
    
    classDef service fill:#f9f,stroke:#333,stroke-width:2px;
    classDef database fill:#bbf,stroke:#333,stroke-width:2px;
    classDef proxy fill:#bfb,stroke:#333,stroke-width:2px;
    classDef client fill:#fbb,stroke:#333,stroke-width:2px;
    classDef frontend fill:#ffd700,stroke:#333,stroke-width:2px;
    
    class Directus,Kong,KongAdmin,KongManager service;
    class DirectusDB,KongDB database;
    class Traefik proxy;
    class Client client;
    class NextJS frontend;
```

## Architecture Explanation

### Components

1. **Traefik Proxy**

   - Acts as the main entry point for all requests
   - Routes requests based on path prefixes
   - Applies middleware for path stripping

2. **Directus CMS**

   - Accessible via `/dmc` and `/dmc/admin` paths
   - Protected from direct access

3. **Kong API Gateway**

   - Proxy accessible via `/apigw`
   - Admin API accessible via `/apigw/admin`
   - Manager UI accessible directly via `http://localhost:8002`

4. **Databases**
   - Directus has its own database
   - Kong uses PostgreSQL for configuration storage

### Request Flow

1. Client sends request to Traefik
2. Traefik routes the request based on path prefix
3. Appropriate middleware strips the prefix
4. Request is forwarded to the target service
5. Service processes the request and returns a response

### Special Case: Kong Manager UI

Due to limitations in how Kong Manager handles base paths, it's accessed directly at port 8002 rather than through the Traefik proxy.
