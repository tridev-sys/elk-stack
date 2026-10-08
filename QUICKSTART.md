# ELK Stack Quick Start Guide

## Starting the Stack

```bash
# 1. Create the shared network (one-time setup)
docker network create shared

# 2. Start ELK services (root directory)
docker-compose up -d

# 3. Wait ~30-60 seconds for Elasticsearch to be ready

# 4. Start Nginx proxy (separate terminal or background)
docker-compose -f proxy_server/docker-compose.yml up -d
```

## Accessing the Services

**Kibana Dashboard (Public):**
- URL: http://localhost:80 (or just http://localhost)
- Username: `admin`
- Password: `admin123`
- Access: Through Nginx reverse proxy with basic auth

**Elasticsearch (Internal Only):**
- URL: http://elasticsearch:9200 (only accessible from within shared network)
- Direct host access: Not exposed (use only through Logstash or Kibana)
- Credentials: elastic / changeme

## Monitoring Service Health

```bash
# Check all containers
docker-compose ps
docker-compose -f proxy_server/docker-compose.yml ps

# Check Elasticsearch health
docker-compose exec elasticsearch curl -s http://localhost:9200/_cluster/health?pretty

# View logs
docker-compose logs -f elasticsearch
docker-compose logs -f kibana
docker-compose logs -f logstash
docker-compose -f proxy_server/docker-compose.yml logs -f proxy_server
```

## Stopping the Stack

```bash
# Stop all services (data persists in volumes)
docker-compose down
docker-compose -f proxy_server/docker-compose.yml down

# Completely remove (WARNING: deletes data!)
docker-compose down -v
docker-compose -f proxy_server/docker-compose.yml down -v
docker network rm shared
```

## Sending Test Logs to Logstash

```bash
# Send a test syslog message
echo "<34>Oct  8 12:31:00 testhost: test log message" | nc -w 1 localhost 5000

# Or use socat for persistent connection
echo "test log" | socat - UDP:localhost:5000
```

Note: Logstash listens on port 5000 and is exposed via Elasticsearch service network.

## Verifying Data Flow

1. Send test logs (see above)
2. Wait 5-10 seconds for processing
3. Go to Kibana: http://localhost (or http://localhost:80)
4. Login with admin/admin123
5. Click "Discover" in left sidebar
6. Create index pattern matching `syslog-*` or `docker-*`
7. View the ingested logs

## Troubleshooting

**Port already in use:**
```bash
# Find what's using port 80
lsof -i :80
# Kill the process or use different port in proxy_server/docker-compose.yml
```

**Elasticsearch won't start:**
```bash
# Check memory allocation to Docker
# Docker Desktop > Settings > Resources > Memory (increase to 4GB+)
docker system prune -a  # Clean up resources if needed
```

**Kibana shows "Unable to connect to Elasticsearch":**
```bash
# Check Elasticsearch is running
docker-compose ps elasticsearch
# View Elasticsearch logs
docker-compose logs elasticsearch
# Verify password in environment variables
```

**Nginx returns 502 Bad Gateway:**
```bash
# Check Kibana container is running
docker-compose ps kibana
# Verify shared network
docker network inspect shared
```

**Cannot access Kibana via http://localhost (port 80):**
```bash
# Verify proxy_server is running
docker ps | grep proxy_server
# Check proxy logs
docker-compose -f proxy_server/docker-compose.yml logs proxy_server
```

## Next Steps

1. Configure Logstash to ingest container logs (update `config/logstash/logstash.conf`)
2. Create Kibana dashboards for your application logs
3. Set up Logstash filters for structured logging
4. Plan EC2 migration (copy volume strategy, update network config)
5. Switch to HTTPS with Let's Encrypt
6. Add X-Pack security for production hardening
