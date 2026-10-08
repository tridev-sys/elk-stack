# ELK Stack Setup Guide

A complete, production-ready ELK stack running in Docker with Nginx authentication. This guide walks you through setup, running, and debugging step by step.

## 📚 What is ELK?

ELK = **Elasticsearch + Logstash + Kibana**

- **Elasticsearch** — Powerful search engine that stores and indexes your logs
- **Logstash** — Pipeline that ingests, processes, and transforms logs
- **Kibana** — Beautiful UI for searching, visualizing, and analyzing logs
- **Nginx** — Reverse proxy with authentication to protect your data

**Real-world scenario:** Your app crashes. Without ELK, you SSH into servers and grep through logs. With ELK, you search in Kibana and find the error in seconds. ✨

---

## 🎯 Quick Start (5 minutes)

### 1️⃣ Prerequisites

```bash
# Check Docker is installed
docker --version
# Should output: Docker version XX.XX.XX

# Check Docker Compose is installed
docker-compose --version
# Should output: Docker Compose version X.XX.X
```

**Don't have Docker?** Install from https://www.docker.com/products/docker-desktop

**Need more resources?** Docker Desktop needs **4GB+ RAM** allocated. Go to Docker → Settings → Resources.

### 2️⃣ Clone & Start

```bash
# Clone the repository
git clone https://github.com/tridev-sys/elk-stack.git
cd elk-stack

# Make sure you're on the dev branch
git checkout dev

# Create the Docker network (required once)
docker network create shared
```

### 3️⃣ Start All Services

```bash
# Start ELK stack (root directory)
docker-compose up -d

# Start Nginx proxy (in separate command)
docker-compose -f proxy_server/docker-compose.yml up -d

# Verify all services are running
docker-compose ps
docker-compose -f proxy_server/docker-compose.yml ps
```

Expected output:
```
NAME          STATUS              PORTS
elasticsearch healthy (1/1)        
kibana        healthy (1/1)        
logstash      healthy (1/1)        
proxy_server  healthy (1/1)  0.0.0.0:80->8080/tcp
```

### 4️⃣ Access Kibana

Open your browser and go to: **http://localhost**

- **Username:** admin
- **Password:** admin123

You should see the Kibana home page. ✅

### 5️⃣ Send a Test Log

```bash
# Send a test syslog message
docker exec logstash bash -c 'echo "<34>Oct 8 test: Hello ELK!" > /dev/udp/127.0.0.1/5000'

# Wait 2 seconds, then check Elasticsearch
curl -u elastic:changeme http://localhost:9200/syslog-*/_count

# Should output: {"count": X, ...} with X >= 1
```

✅ If you see `count: 1` (or higher), **your stack is working!**

---

## 🔧 Step-by-Step Guide to Understanding the System

### Step 1: Understanding the Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Application                        │
│                  (Docker containers)                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                  (sends logs to)
                         │
                         ▼
            ┌────────────────────────┐
            │      Logstash:5000     │
            │   (ingestion pipeline) │
            └────────────┬───────────┘
                         │
           (processes & transforms logs)
                         │
                         ▼
        ┌─────────────────────────────────┐
        │  Elasticsearch:9200              │
        │  (indexes & stores logs)        │
        └────────────┬────────────────────┘
                     │
                (searches & retrieves)
                     │
                     ▼
        ┌─────────────────────────────────┐
        │     Kibana:5601                 │
        │  (visualization dashboard)     │
        └────────────┬────────────────────┘
                     │
             (proxied through Nginx)
                     │
                     ▼
        ┌─────────────────────────────────┐
        │    Nginx:80 (with auth)         │
        │  (http://localhost)            │
        └─────────────────────────────────┘
```

**What this means:**
- Logs flow one direction: App → Logstash → Elasticsearch → Kibana
- Nginx sits in front, protecting Kibana with a username/password
- Docker network `shared` connects all containers invisibly

### Step 2: Verify Each Service

```bash
# 1. Check Elasticsearch is healthy
curl -u elastic:changeme http://localhost:9200/_cluster/health
# Look for "status": "green" ✅

# 2. Check Kibana is ready
curl -u admin:admin123 http://localhost/api/status
# Should return JSON with lots of data

# 3. Check Logstash is running
docker-compose logs logstash | tail -20
# Look for lines like "Pipeline started" ✅

# 4. Check Nginx is forwarding
curl -v http://localhost
# Should show: HTTP/1.1 401 Unauthorized (that's correct! we need auth)
```

### Step 3: Send Logs and Verify

**Method 1: Via Docker (Recommended for Testing)**
```bash
# Send a syslog message
docker exec logstash bash -c 'echo "<34>Oct 8 app: Error connecting to database" > /dev/udp/127.0.0.1/5000'

# Verify it was indexed
curl -u elastic:changeme http://localhost:9200/syslog-*/_search?pretty
```

**Method 2: From Your Local Machine**
```bash
# Install netcat if not present
# macOS: brew install netcat
# Ubuntu: sudo apt-get install netcat

# Send a message
echo "<34>Oct 8 test: Message from my machine" | nc -w0 -u localhost 5000

# Verify in Elasticsearch
curl -u elastic:changeme http://localhost:9200/syslog-*/_count
```

**Method 3: JSON Logs (TCP Port 5001)**
```bash
# Send JSON structured log
echo '{"level":"error","message":"Database connection failed","service":"api"}' | nc localhost 5001

# Verify
curl -u elastic:changeme 'http://localhost:9200/docker-*/_search?pretty'
```

### Step 4: View in Kibana UI

1. Open http://localhost (login: admin/admin123)
2. Go to **Analytics → Discover**
3. Select a data view (should auto-create `syslog-*` or `docker-*`)
4. You should see your test log entries!
5. Click on any log to see all fields

---

## 🐛 Debugging: Common Issues & Solutions

### Issue 1: "Connection refused" when accessing http://localhost

**Symptoms:**
```
curl: (7) Failed to connect to localhost port 80
```

**Debugging steps:**
```bash
# Step 1: Check if Nginx is running
docker-compose -f proxy_server/docker-compose.yml ps

# Step 2: Check Nginx logs
docker-compose -f proxy_server/docker-compose.yml logs proxy_server

# Step 3: Verify port 80 is listening
lsof -i :80  # macOS/Linux

# Step 4: Restart Nginx
docker-compose -f proxy_server/docker-compose.yml restart proxy_server
```

**Solution:** Make sure proxy_server is running and healthy (status = "healthy")

---

### Issue 2: "401 Unauthorized" error

**Symptoms:**
```
curl -v http://localhost
# Returns: HTTP/1.1 401 Unauthorized
```

**This is CORRECT!** Nginx is working. You need to provide credentials:

```bash
# Correct way with credentials
curl -u admin:admin123 http://localhost

# If you get 401, credentials are wrong. Check htpasswd file:
docker exec proxy_server cat /etc/nginx/.htpasswd
```

---

### Issue 3: Logs aren't appearing in Elasticsearch

**Debugging checklist:**

```bash
# 1. Is Logstash running?
docker-compose ps logstash
# Should show "healthy"

# 2. Are logs reaching Logstash?
docker-compose logs logstash | grep -i "received\|event"
# Should show processing messages

# 3. Can Logstash reach Elasticsearch?
docker exec logstash curl -s http://elasticsearch:9200/_cluster/health
# Should return status: "green"

# 4. Check Logstash config
docker exec logstash cat /usr/share/logstash/pipeline/logstash.conf

# 5. Send a test log and watch Logstash
docker-compose logs -f logstash &
docker exec logstash bash -c 'echo "<34>Oct 8 debug: test message" > /dev/udp/127.0.0.1/5000'
# Ctrl+C to stop logs

# 6. Count documents in Elasticsearch
curl -u elastic:changeme http://localhost:9200/syslog-*/_count
```

**Common causes:**
- Logstash crashed (restart: `docker-compose restart logstash`)
- Network issue (verify `docker network ls | grep shared`)
- Port conflict (check if 5000/5001 are in use: `lsof -i :5000`)

---

### Issue 4: Elasticsearch "unhealthy"

**Debugging:**

```bash
# Check Elasticsearch logs
docker-compose logs elasticsearch

# Check cluster health
curl -u elastic:changeme http://localhost:9200/_cluster/health?pretty

# Common issue: Out of memory
docker stats elasticsearch
# If MEMORY % is very high, increase Docker Desktop RAM allocation

# Restart Elasticsearch
docker-compose restart elasticsearch
docker-compose logs -f elasticsearch  # Wait for "ready_for_bootstrap" message
```

---

### Issue 5: "Network shared not found"

**Symptoms:**
```
Error response from daemon: network shared not found
```

**Solution:**

```bash
# Create the network (required once)
docker network create shared

# Verify it exists
docker network ls | grep shared
```

---

## 🧪 Automated Testing

Run the quick verification script:

```bash
# Run 5-point health check
bash QUICK_TEST.sh

# Expected output:
# ✅ Test 1: Authentication enforced
# ✅ Test 2: Services healthy
# ✅ Test 3: Logs can be sent
# ✅ Test 4: Documents indexed
# ✅ Test 5: Indexes available
```

If any test fails, it will show the exact command that failed for debugging.

---

## 📚 Learn ELK: Next Steps

### For Beginners
1. Read **LEARNING_ELK.md** (complete guide with exercises)
2. Follow the hands-on exercises (send logs, search, create dashboards)
3. Experiment with Kibana's Discover and Visualize features

### For Intermediate Users
1. Read **HOW_ELK_WORKS.md** (architecture deep-dive)
2. Customize Logstash filters for your use cases
3. Create custom Kibana dashboards and alerts

### For Advanced Users
1. Set up log parsing for specific formats (JSON, structured, etc.)
2. Implement log retention policies
3. Scale to multi-node Elasticsearch for high volume

---

## 🛑 Stop & Clean Up

### Stop Services (Keep Data)
```bash
# Stop ELK stack
docker-compose down

# Stop Nginx
docker-compose -f proxy_server/docker-compose.yml down

# Data persists in Docker volumes
```

### Stop & Delete Everything
```bash
# Stop all services
docker-compose down -v
docker-compose -f proxy_server/docker-compose.yml down -v

# Delete the Docker network
docker network rm shared

# Delete all ELK data permanently
docker volume rm elasticsearch_data

# WARNING: ☝️ This deletes all logs. Only do if you're starting fresh.
```

---

## 📋 File Guide

```
elk-stack/
├── docker-compose.yml              # ELK stack (Elasticsearch, Kibana, Logstash)
├── config/logstash/logstash.conf   # Log processing pipeline
├── proxy_server/
│   ├── docker-compose.yml          # Nginx configuration
│   └── config/
│       ├── nginx.conf              # Nginx setup
│       └── htpasswd                # Username/password (admin:admin123)
├── LEARNING_ELK.md                 # Complete learning guide (1,300+ lines)
├── HOW_ELK_WORKS.md                # Architecture deep-dive
├── TESTING.md                      # Testing procedures
├── QUICKSTART.md                   # Operations quick reference
├── QUICK_TEST.sh                   # Automated verification
├── claude.md                       # Project specification
└── manifest.json                   # Complete inventory
```

---

## 🔐 Security Notes

### Current Setup (Development)
- ✅ HTTP only (fine for laptop/testing)
- ✅ Basic auth on Nginx (username/password)
- ✅ Elasticsearch credentials: elastic / changeme
- ⚠️ No HTTPS (don't use in production)

### For Production
1. Enable HTTPS with Let's Encrypt
2. Use strong passwords (change `admin123`)
3. Enable X-Pack security in Elasticsearch
4. Use VPC/security groups to restrict access
5. Set up log retention policies

---

## 💡 Tips & Tricks

### See what's in Elasticsearch
```bash
# List all indexes
curl -u elastic:changeme http://localhost:9200/_cat/indices

# See sample documents
curl -u elastic:changeme http://localhost:9200/syslog-*/_search?pretty | head -50

# Delete an index
curl -X DELETE -u elastic:changeme http://localhost:9200/syslog-2026.10.08
```

### Watch logs in real-time
```bash
# ELK stack logs
docker-compose logs -f

# Just Logstash
docker-compose logs -f logstash

# Just Elasticsearch (verbose)
docker-compose logs -f elasticsearch | grep -i error
```

### Check resource usage
```bash
# See memory/CPU of each service
docker stats
```

### Reset Everything (Start Fresh)
```bash
docker-compose down -v
docker-compose -f proxy_server/docker-compose.yml down -v
docker network rm shared
docker network create shared
docker-compose up -d
docker-compose -f proxy_server/docker-compose.yml up -d
```

---

## 🤝 Getting Help

1. **Logs are key** — Always check logs first:
   ```bash
   docker-compose logs [service-name]
   ```

2. **Check TESTING.md** — Has 10-point verification checklist

3. **Read error carefully** — Errors usually tell you what's wrong

4. **Try the automated test** — `bash QUICK_TEST.sh` pinpoints issues

5. **Health checks** — Docker reports service health automatically

---

## ✅ You're Ready!

You now have a complete ELK monitoring stack. Start by:

1. ✅ **Verify:** Run `docker-compose ps` to ensure all services are healthy
2. ✅ **Test:** Send a log with `docker exec logstash bash -c 'echo "<34>Oct 8 test: Hello" > /dev/udp/127.0.0.1/5000'`
3. ✅ **Explore:** Open http://localhost and search your logs in Kibana
4. ✅ **Learn:** Read LEARNING_ELK.md for comprehensive understanding

**Questions?** Check the debugging section above or read the detailed documentation files.

Happy logging! 🚀
