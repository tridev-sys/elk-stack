# ELK Stack Setup for Docker Container Monitoring

**Project:** Install ELK Stack in Docker to Monitor Containers  
**Date:** 2026-10-08  
**Environment:** Docker Desktop (laptop) → Docker Compose on AWS EC2 (production)  
**Status:** ✅ Fully Operational — Complete

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
├── docker-compose.yml              # ELK stack orchestration
├── config/
│   └── logstash/
│       └── logstash.conf            # Logstash pipeline config (syslog:5000, JSON:5001)
├── proxy_server/
│   ├── docker-compose.yml           # Nginx reverse proxy
│   └── config/
│       ├── nginx.conf               # Nginx configuration
│       └── htpasswd                 # HTTP Basic Auth (admin:admin123)
├── LEARNING_ELK.md                  # 📚 Complete learning guide (1,317 lines)
├── HOW_ELK_WORKS.md                 # 📚 Architecture deep-dive (595 lines)
├── TESTING.md                       # 📚 Verification & troubleshooting (133 lines)
├── QUICK_TEST.sh                    # 🧪 Automated health check script
├── QUICKSTART.md                    # Quick start operations guide
├── claude.md                        # This file (project specification)
├── scratchpad.md                    # DevOps notes and session log
├── manifest.json                    # Complete project inventory
└── [data volumes managed by Docker]
```

---

## Implementation Status

### ✅ Completed
1. ✅ Created directory structure and config files
2. ✅ Set up the `shared` Docker network (persistent, cross-compose)
3. ✅ Built `docker-compose.yml` for ELK stack with persistent volumes
4. ✅ Built `proxy_server/docker-compose.yml` for Nginx with basic auth
5. ✅ Generated htpasswd credentials (admin:admin123)
6. ✅ Verified end-to-end connectivity and authentication (7/7 tests passed)
7. ✅ Created comprehensive learning materials and testing infrastructure
8. ✅ Documented system architecture and operational procedures

### 📚 Learning Materials Created
- **LEARNING_ELK.md** (1,317 lines) — Complete educational guide covering fundamentals to advanced topics
- **HOW_ELK_WORKS.md** (595 lines) — Architecture deep-dive with real-world examples
- **TESTING.md** (133 lines) — Verification checklist and troubleshooting guide
- **QUICK_TEST.sh** — Automated 5-point system verification script

### 🎯 Next Steps (Suggested)
1. **Learn by Doing** — Follow hands-on exercises in LEARNING_ELK.md (Levels 1-4)
2. **Create Dashboards** — Build custom visualizations in Kibana UI
3. **EC2 Migration** — Deploy to AWS using documented scaling strategy
4. **Production Hardening** — Enable HTTPS, X-Pack security, alerting

---

## Learning Resources

This project includes comprehensive educational materials designed to build understanding from fundamentals to advanced ELK concepts:

### 📖 Documentation Files
- **`LEARNING_ELK.md`** — Start here for complete learning path (1,317 lines)
  - The Problem ELK Solves (before/after comparison)
  - Core concepts (logs, indexing, documents, queries)
  - Component deep-dives with explanations
  - Step-by-step data flow (61-second journey of a log entry)
  - 5 hands-on exercises with code
  - 3 real-world scenarios (security, performance, debugging)
  - Advanced topics and cheat sheet

- **`HOW_ELK_WORKS.md`** — Architecture and technical deep-dive (595 lines)
  - ASCII diagrams of system architecture
  - Logstash pipeline detailed explanation
  - Elasticsearch indexing and inverted index mechanics
  - Kibana features and UI walkthrough
  - Nginx authentication flow
  - Real-world example: complete log journey

- **`TESTING.md`** — Verification and troubleshooting (133 lines)
  - 10-point verification checklist
  - Port reference guide
  - Troubleshooting section
  - Quick test templates

### 🧪 Testing Tools
- **`QUICK_TEST.sh`** — Automated system verification (executable)
  - 5-point health check: authentication, health, logging, verification, indexing
  - Use before/after changes to ensure system stability
  - Run: `bash QUICK_TEST.sh`

### 🎓 Recommended Learning Path
1. **Day 1:** Read "The Problem ELK Solves" + "Core Concepts" in LEARNING_ELK.md
2. **Day 2:** Read "Component Deep Dive" + "Data Flow Step-by-Step"
3. **Day 3:** Complete Exercises 1-3 (send logs, search, custom fields)
4. **Day 4:** Complete Exercises 4-5 (Kibana UI, create visualization)
5. **Advanced:** Read "Real-World Scenarios" and "Advanced Topics"

---

## Operational Guide

### Quick Start

See `QUICKSTART.md` for starting, stopping, and accessing the stack.

### Default Credentials

- **Kibana (via Nginx proxy):** admin / admin123 on http://localhost (port 80)
- **Elasticsearch:** elastic / changeme (internal only, not exposed to host)

### Port Exposure Strategy

- **Exposed to Host:** Port 80 (Nginx proxy via proxy_server/docker-compose.yml)
- **Internal Only (expose keyword):** Ports 9200, 9300 (Elasticsearch), 5601 (Kibana), 5000 (Logstash)
- All ELK services communicate via `shared` Docker network

### Persistent Data

- Elasticsearch data stored in Docker volume `elasticsearch_data`
- Volumes survive container/compose file deletion
- To permanently delete: `docker volume rm elasticsearch_data`

### Service Health Checks

All services have healthchecks configured:
- Elasticsearch: Checks cluster status
- Kibana: Checks API status
- Logstash: Checks pipeline status
- Nginx: Checks status endpoint

### Container Logs

```bash
docker-compose logs -f [service-name]
docker-compose -f proxy_server/docker-compose.yml logs -f proxy_server
```

---

## Notes

- **Resources:** Laptop should have 4GB+ RAM allocated to Docker Desktop for comfortable operation
- **Log Retention:** Medium volume (10s GB/day, 30 days retention)
- **Security:** HTTP only for now; HTTPS can be added later with Let's Encrypt
- **Future Scaling:** This design can upgrade to multi-node Elasticsearch on EC2 by modifying compose file only

---

*Last Updated: 2026-10-08 — Status: Complete with comprehensive learning materials and testing infrastructure*
