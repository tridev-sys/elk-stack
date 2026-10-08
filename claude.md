# ELK Stack Setup for Docker Container Monitoring

**Project:** Install ELK Stack in Docker to Monitor Containers  
**Date:** 2026-10-08  
**Environment:** Docker Desktop (laptop) → Docker Compose on AWS EC2 (production)  
**Status:** Design Approved — Ready for Implementation

---

## Project Goals

1. Set up a monitoring infrastructure for Docker containers using the ELK stack
2. Start with a simple single-node setup on the developer's laptop
3. Design for portability to AWS EC2 with Docker Compose
4. Implement basic authentication via Nginx reverse proxy (HTTP for now)
5. Ensure persistent volumes that survive container/compose file recreation

---

## Design Overview

### Architecture: Single-Node ELK with Separate Nginx Proxy

#### Components
- **Elasticsearch** — Log storage and indexing (port 9200 internally)
- **Kibana** — Visualization and dashboard UI (port 5601 internally)
- **Logstash** — Log ingestion and transformation (port 5000 for syslog)
- **Nginx (proxy_server)** — Reverse proxy with basic auth (port 8080 externally)

#### Data Flow
```
Docker containers → Logstash:5000 → Elasticsearch:9200 → Kibana:5601 → Nginx:8080
                                                                           ↓
                                                                  User (browser)
```

#### Deployment Strategy

**Two Separate Docker Compose Files:**

1. **Root: `docker-compose.yml`** (ELK Stack)
   - Elasticsearch container
   - Kibana container
   - Logstash container
   - All on `shared` network (internal)

2. **`proxy_server/docker-compose.yml`** (Nginx Proxy)
   - Nginx container (`proxy_server`)
   - On `shared` network
   - Exposes port 8080 to host

#### Networking

- **External Docker Network:** `shared`
  - Created once, persists across container/compose resets
  - Both compose files attach to it
  - Containers discover each other by service name (e.g., `kibana`, `elasticsearch`)

#### Persistent Storage

- **Named Volumes** (Docker-managed)
  - `elasticsearch_data` — Elasticsearch data directory
  - Survives container deletion and recreation
  - On laptop: stored at `/var/lib/docker/volumes/elasticsearch_data/_data`
  - On EC2: backed by EBS volumes (volume mount paths documented for migration)

- **Bind Mounts** (Config Files)
  - Logstash config: `./config/logstash/logstash.conf` → `/usr/share/logstash/pipeline/`
  - Nginx config: `proxy_server/config/nginx.conf` → `/etc/nginx/nginx.conf`
  - Nginx htpasswd: `proxy_server/config/htpasswd` → `/etc/nginx/.htpasswd`

---

## Directory Structure

```
/Users/tridevguha/Desktop/Projects/ELK/
├── docker-compose.yml              # ELK stack (Elasticsearch, Kibana, Logstash)
├── config/
│   └── logstash/
│       └── logstash.conf            # Logstash pipeline config
├── proxy_server/
│   ├── docker-compose.yml           # Nginx proxy server
│   └── config/
│       ├── nginx.conf               # Nginx reverse proxy config
│       └── htpasswd                 # Basic auth credentials
├── claude.md                        # This file (project documentation)
├── scratchpad.md                    # DevOps notes and implementation log
└── [data volumes managed by Docker]
```

---

## Implementation Plan (Next Steps)

1. Create directory structure and config files
2. Set up the `shared` Docker network
3. Build `docker-compose.yml` for ELK stack with persistent volumes
4. Build `proxy_server/docker-compose.yml` for Nginx with basic auth
5. Generate htpasswd credentials
6. Test connectivity and logging flow
7. Document EC2 migration steps

---

## Notes

- **Resources:** Laptop should have 4GB+ RAM allocated to Docker Desktop for comfortable operation
- **Log Retention:** Medium volume (10s GB/day, 30 days retention)
- **Security:** HTTP only for now; HTTPS can be added later with Let's Encrypt
- **Future Scaling:** This design can upgrade to multi-node Elasticsearch on EC2 by modifying compose file only

---

*Last Updated: 2026-10-08*
