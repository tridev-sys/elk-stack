# ELK Setup - Scratchpad Notes

**DevOps Implementation Log**

## Session: 2026-10-08 - Initial Setup

### Design Decisions Made
- ✅ Chose single-node approach (Approach A) over multi-node
- ✅ Separated Nginx into its own directory and docker-compose for modularity
- ✅ Using external `shared` network for flexibility
- ✅ Named volumes for persistent storage (survives container recreation)
- ✅ HTTP only for now (security can be upgraded later)

### Key Architecture Points
- Two docker-compose files (ELK in root, Nginx in proxy_server/)
- Shared network connecting both stacks
- Elasticsearch as single node (no clustering yet)
- Logstash listens on 5000 for incoming logs
- Kibana accessed through Nginx reverse proxy on port 8080
- Basic auth via htpasswd file

### Configuration Files To Create
- [ ] `docker-compose.yml` - ELK stack
- [ ] `proxy_server/docker-compose.yml` - Nginx
- [ ] `config/logstash/logstash.conf` - Logstash pipeline
- [ ] `proxy_server/config/nginx.conf` - Nginx reverse proxy
- [ ] `proxy_server/config/htpasswd` - Basic auth credentials

### Docker Volumes
- `elasticsearch_data` - Main data volume for Elasticsearch

### Docker Network
- `shared` - External network, must be created before running compose files

### Testing Plan
1. Create network: `docker network create shared`
2. Start ELK stack: `docker-compose up -d` (from root)
3. Start Nginx: `docker-compose -f proxy_server/docker-compose.yml up -d`
4. Test connectivity: `curl -u user:pass http://localhost:8080` → should redirect to Kibana
5. Verify Elasticsearch health via Kibana UI

### Environment Variables (TBD)
- Elasticsearch cluster name
- Elasticsearch node name
- Kibana default user/password
- Nginx proxy user/password

### Known Constraints
- Medium log volume (~10-30 GB/day, 30 day retention)
- Single node (no HA)
- HTTP only (upgrade later)
- Laptop resources: needs 4GB+ RAM in Docker Desktop

### EC2 Migration Notes (For Later)
- Volume paths need adjustment for EBS mounts
- Security groups need to allow 8080 from VPC
- Environment variables for production (different passwords, heap size)
- Consider adding CloudWatch monitoring alongside ELK

### Questions/Todos
- [ ] Generate secure htpasswd credentials
- [ ] Determine Elasticsearch heap size for laptop (default 1GB might be enough)
- [ ] Plan log ingestion strategy (syslog, file, Docker driver?)
- [ ] Test with dummy container logs first

---

*Last Updated: 2026-10-08*
