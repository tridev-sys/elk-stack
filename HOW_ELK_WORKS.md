# How ELK Stack Works

**ELK** = **E**lasticsearch + **L**ogstash + **K**ibana

An integrated logging and analytics platform for collecting, processing, storing, and visualizing logs.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA FLOW IN ELK                          │
└─────────────────────────────────────────────────────────────────┘

SOURCES                 PROCESSING               STORAGE              VISUALIZATION
(Apps/Containers)       (Transformation)         (Indexing)           (Dashboards)
    │                        │                       │                     │
    ↓                        ↓                       ↓                     ↓
┌─────────┐            ┌──────────┐          ┌──────────────┐       ┌──────────┐
│ Docker  │            │ Logstash │          │Elasticsearch│       │  Kibana  │
│Containers│──syslog──→│ (port    │─ingest→  │  (port 9200) │──────→│(port5601)│
│App Logs │  JSON on   │5000/5001)│          │              │       │          │
│Syslog   │  ports     │          │          │  Indexes:    │       │Dashboard │
│  Etc.   │            │ Pipeline │          │ syslog-*    │       │ Search   │
└─────────┘            │          │          │ docker-*    │       │ Analyze  │
                       │ - Parse  │          │              │       └──────────┘
                       │ - Filter │          │ Index each   │            ↑
                       │ - Enrich │          │ log by type  │            │
                       │ - Route  │          │ & timestamp  │       Via Nginx
                       └──────────┘          └──────────────┘       (Port 80)
                                                   ↓
                                            User: admin/admin123
```

---

## 🔍 Component Details

### 1. **LOGSTASH** — Log Ingestion & Processing

**What it does:** Collects logs from various sources, transforms them, and sends to Elasticsearch.

**In your setup:**
- **Listens on port 5000** (syslog protocol - UDP + TCP)
- **Listens on port 5001** (JSON logs - TCP only)
- **Configuration:** `config/logstash/logstash.conf`

**Processing Pipeline:**

```
INPUT (Collect)          FILTER (Transform)       OUTPUT (Send)
        ↓                        ↓                       ↓
┌──────────────┐         ┌──────────────┐       ┌──────────────┐
│ Syslog on    │         │ Parse fields │       │Elasticsearch │
│ port 5000    │────────→│ Add metadata │──────→│ (port 9200)  │
│              │         │ Create index │       │              │
│ TCP JSON on  │         │ names        │       │ Credentials: │
│ port 5001    │         │              │       │ elastic/     │
└──────────────┘         └──────────────┘       │ changeme     │
                                                └──────────────┘
```

**Example Processing:**
```json
INPUT (raw syslog):
"<34>Oct 8 12:31:00 myserver: app crashed"

AFTER FILTER:
{
  "@timestamp": "2026-10-08T12:31:00.000Z",
  "message": "app crashed",
  "host": "myserver",
  "type": "syslog",
  "@metadata": {
    "index_name": "syslog-2026.10.08"
  }
}

OUTPUT → Elasticsearch with index: "syslog-2026.10.08"
```

**Key Settings:**
```conf
syslog {
  port => 5000              # Listen for syslog messages
  type => "syslog"          # Tag as syslog type
}

tcp {
  port => 5001              # Listen for JSON messages
  type => "docker"          # Tag as docker type
  codec => "json"           # Parse as JSON
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]  # Send to Elasticsearch
    index => "%{[@metadata][index_name]}"  # Use dynamic index names
    user => "elastic"                # Credentials
    password => "changeme"
  }
}
```

---

### 2. **ELASTICSEARCH** — Log Storage & Indexing

**What it does:** Stores logs in searchable indexes and provides fast full-text search.

**In your setup:**
- **Listens on port 9200** (REST API - internal only)
- **Single-node cluster** (no replication)
- **Data stored in:** Docker volume `elasticsearch_data`

**Index Structure:**

```
Index Name: "syslog-2026.10.08"
├── Settings (How to index)
│   ├── Number of shards: 1
│   ├── Replicas: 0
│   └── Refresh interval: 1s
│
├── Mappings (Field definitions)
│   ├── @timestamp (date)
│   ├── message (text - searchable)
│   ├── host (keyword - exact match)
│   ├── type (keyword)
│   └── ... (other fields)
│
└── Documents (Actual logs)
    ├── Doc 1: {"@timestamp": "2026-10-08T12:31:00Z", "message": "...", ...}
    ├── Doc 2: {"@timestamp": "2026-10-08T12:32:00Z", "message": "...", ...}
    └── Doc N: {...}
```

**How Indexing Works:**

```
Logstash sends JSON doc
        ↓
Elasticsearch receives via HTTP
        ↓
Analyzes fields using mappings
        ↓
Creates inverted index (for searching)
        ↓
Stores document in index shard
        ↓
Ready for search within ~1 second
```

**Example Search Query (via REST API):**
```bash
curl -u elastic:changeme 'http://localhost:9200/syslog-*/_search' -H 'Content-Type: application/json' -d '{
  "query": {
    "match": {
      "message": "crashed"
    }
  }
}'

Response:
{
  "hits": {
    "total": {"value": 5},
    "hits": [
      {
        "_id": "1",
        "_source": {
          "@timestamp": "2026-10-08T12:31:00Z",
          "message": "app crashed",
          "host": "server1"
        }
      }
    ]
  }
}
```

**Daily Indexes:**
- Every day, Logstash creates new index: `syslog-2026.10.09`, `syslog-2026.10.10`, etc.
- Old indexes can be archived or deleted (e.g., keep 30 days)
- Faster queries (searches only recent data)

---

### 3. **KIBANA** — Log Analysis & Visualization

**What it does:** Web UI for searching logs, creating dashboards, and analyzing patterns.

**In your setup:**
- **Listens on port 5601** (internal only)
- **Accessed via Nginx reverse proxy** on port 80 with basic auth
- **Credentials:** admin / admin123

**Main Features:**

```
┌──────────────────────────────────────────────────┐
│              KIBANA DASHBOARD                    │
├──────────────────────────────────────────────────┤
│                                                  │
│  🔍 DISCOVER                                     │
│  ├─ Search logs in real-time                    │
│  ├─ Filter by field values                      │
│  ├─ View log details                            │
│  └─ Timeline visualization                      │
│                                                  │
│  📊 VISUALIZE                                    │
│  ├─ Line charts (errors over time)              │
│  ├─ Pie charts (logs by host)                   │
│  ├─ Gauge (error rate %)                        │
│  └─ Custom visualizations                       │
│                                                  │
│  📋 DASHBOARDS                                   │
│  ├─ Combine multiple visualizations             │
│  ├─ Real-time updates                           │
│  ├─ Share with team                             │
│  └─ Drill-down analysis                         │
│                                                  │
│  ⚙️ MANAGEMENT                                   │
│  ├─ Index patterns (syslog-*, docker-*)         │
│  ├─ Saved searches                              │
│  ├─ Alerts (coming soon)                        │
│  └─ User management                             │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Workflow - Using Kibana:**

```
Step 1: Create Index Pattern
   → Go to Management → Index Patterns
   → Add: "syslog-*" or "docker-*"
   → Select: "@timestamp" as time field
   → Save

Step 2: Discover Logs
   → Click "Discover"
   → See all logs from selected index
   → Timeline shows log volume over time
   → Table shows individual log entries

Step 3: Filter & Search
   → Search bar: message:"error"
   → Filter: host:server1
   → Time picker: Last 24 hours
   → See matching results update in real-time

Step 4: Analyze Patterns
   → Create visualization: Bar chart of errors by host
   → Add to dashboard
   → Share with team
```

---

### 4. **NGINX** — Authentication & Access Control

**What it does:** Acts as reverse proxy, adds basic authentication.

**In your setup:**
- **Listens on port 80** (public, host-accessible)
- **Proxies to Kibana** on port 5601
- **Authentication:** htpasswd file (admin/admin123)
- **Configuration:** `proxy_server/config/nginx.conf`

**Request Flow:**

```
User Browser (localhost:80)
        ↓
Nginx (port 80)
  ├─ Check: Authorization header present?
  │  └─ NO → Return 401 Unauthorized + "Basic realm"
  │  └─ YES → Validate credentials against htpasswd
  │          └─ Invalid → Return 401
  │          └─ Valid → Continue
  ├─ Add headers (X-Forwarded-For, etc.)
  └─ Forward to Kibana:5601
        ↓
Kibana (internal port 5601)
        ↓
Kibana Response (HTML page)
        ↓
Return to user browser
```

**Example:**
```bash
# Without auth → 401
curl -v http://localhost/
< HTTP/1.1 401 Unauthorized
< WWW-Authenticate: Basic realm="ELK Stack - Restricted Access"

# With correct auth → 302 redirect to Kibana
curl -u admin:admin123 http://localhost/
< HTTP/1.1 302 Found
< Location: /app/kibana

# Browser follows redirect and loads Kibana dashboard
```

---

## 📊 Complete Data Journey Example

**Scenario:** Docker container logs "Database connection timeout" error

### Step 1: Log Generated
```
Container: myapp
Timestamp: 2026-10-08T14:30:45Z
Message: "Database connection timeout after 30s"
```

### Step 2: Log Sent to Logstash
```bash
Your app sends:
echo '{"message":"Database connection timeout after 30s","service":"myapp"}' \
  | nc localhost 5001
```

### Step 3: Logstash Processes
```
INPUT: JSON on TCP port 5001
  ↓
FILTER: Parse JSON
  - Extract fields: message, service
  - Add: @timestamp, @metadata[index_name]="docker-2026.10.08"
  ↓
OUTPUT: Send to Elasticsearch
  - HTTP POST to http://elasticsearch:9200
  - Index: docker-2026.10.08
  - Document ID: auto-generated
```

### Step 4: Elasticsearch Indexes
```
Receives JSON document from Logstash
  ↓
Analyzes against index mapping
  ↓
Creates inverted index:
  - "Database" → doc_id
  - "connection" → doc_id
  - "timeout" → doc_id
  - "myapp" → doc_id
  ↓
Stores document
  ↓
Ready for search (~1 second)
```

### Step 5: User Searches in Kibana
```
1. Open browser: http://localhost
2. Login: admin / admin123
3. Go to Discover
4. Search: service:myapp AND message:timeout
5. Results show:
   - One matching log entry
   - Timestamp: 2026-10-08T14:30:45Z
   - Full message visible
   - Related logs from same service
```

---

## 🔗 Networking & Security

### Internal Network (Shared Docker Network)
```
┌─────────────────────────────────────────────────┐
│          SHARED DOCKER NETWORK                  │
├─────────────────────────────────────────────────┤
│                                                 │
│  elasticsearch:9200 ←───────────┐              │
│        ↑                        │              │
│        │                    kibana:5601        │
│        │                        │              │
│    logstash:5000/5001 ──→  elasticsearch       │
│        ↑                                        │
│        │ (syslog/JSON)                         │
│        │                                        │
│   proxy_server:8080                           │
│        ↑                                        │
│        │ (via host network)                    │
│   HOST:80 (external)                           │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Port Exposure Strategy

| Service | Container Port | Host Port | Access | Purpose |
|---------|---|---|---|---|
| **Elasticsearch** | 9200 | ❌ NONE | Internal only | API (Kibana, Logstash) |
| **Elasticsearch** | 9300 | ❌ NONE | Internal only | Node communication |
| **Kibana** | 5601 | ❌ NONE | Via Nginx | Web UI (internal) |
| **Logstash** | 5000 | ❌ NONE | Internal only | Syslog (use host interface) |
| **Logstash** | 5001 | ❌ NONE | Internal only | JSON (use host interface) |
| **Nginx** | 8080 | ✅ 80 | Public | Kibana access with auth |

**Why this design?**
- Only Nginx exposed to host (single entry point)
- All backend services hidden (security)
- Authentication enforced at boundary
- Services communicate internally via Docker network
- No direct exposure of passwords/APIs

---

## 📈 Use Cases & Queries

### 1. Real-time Error Monitoring
```
Search: severity:ERROR AND timestamp:[now-1h TO now]
Result: All errors in last hour, grouped by time
```

### 2. Service Performance Analysis
```
Search: service:api-gateway
Visualize: Response time trend (line chart)
Dashboard: Monitor SLA compliance
```

### 3. Security Audit Trail
```
Search: action:login AND status:failed
Result: All failed login attempts with IPs
Alert: If > 5 in 5 minutes → suspicious activity
```

### 4. Capacity Planning
```
Search: container:*
Visualize: Disk usage trend over 30 days
Result: Forecast when storage runs out
```

### 5. Debugging Production Issues
```
1. Search: trace_id:abc123
2. See all logs with same trace_id (request journey)
3. Understand failure in context
4. Find root cause across microservices
```

---

## 🚀 Key Concepts

### Index
**What:** A collection of documents (logs) of the same type
- Similar to a database table
- Stored on disk (persistent volume)
- Searchable via Elasticsearch API
- Example: `syslog-2026.10.08` contains all syslog messages for that day

### Shard
**What:** A partition of an index for parallel processing
- Your setup: 1 shard per index
- Production: Multiple shards for distributed search
- Example: Search `syslog-2026.10.08` searches across all shards

### Document
**What:** A single log entry (JSON object)
- Stored in an index
- Has unique ID and timestamp
- Contains all log fields (message, host, severity, etc.)

### Mapping
**What:** Definition of index structure (like database schema)
- Defines field types: text, keyword, date, number, etc.
- Affects how logs are indexed and searched
- `text` fields: full-text searchable
- `keyword` fields: exact match only (fast)

### Pipeline (Logstash)
**What:** Processing steps for logs
1. **Input:** Where logs come from (syslog, file, API)
2. **Filter:** How to transform (parse, add fields, drop)
3. **Output:** Where to send (Elasticsearch, file, S3)

---

## 🔧 Troubleshooting

### "No data in Kibana"
**Causes:**
1. Logs not sent to Logstash
2. Logstash not forwarding to Elasticsearch
3. Index not created yet

**Fix:**
```bash
# Check if index exists
curl -u elastic:changeme 'http://localhost:9200/_cat/indices'

# Send test log manually
echo "<34>Oct 8 test" | nc localhost 5000

# Check Logstash logs
docker-compose logs logstash | tail -20

# Check Elasticsearch has document
curl -u elastic:changeme 'http://localhost:9200/syslog-*/_count'
```

### "Logstash connection refused"
**Cause:** Elasticsearch unreachable

**Fix:**
```bash
# Verify Elasticsearch is running
docker-compose ps elasticsearch

# Check from Logstash container
docker exec logstash curl -s http://elasticsearch:9200/_cluster/health
```

### "Kibana shows 'Elasticsearch not ready'"
**Cause:** Kibana starting before Elasticsearch

**Fix:**
```bash
# Check Elasticsearch health
curl -u elastic:changeme 'http://localhost:9200/_cluster/health'

# Status should be "green" (all shards available)
```

---

## 📚 Learning Path

1. **Send test logs** → Understand input methods
2. **View in Discover** → Learn basic searching
3. **Create filters** → Practice query syntax
4. **Build visualizations** → See data patterns
5. **Create dashboards** → Combine insights
6. **Set up alerts** → Automate monitoring
7. **Scale cluster** → Production hardening

---

## 🎯 Quick Reference Commands

```bash
# Check all services
docker-compose ps

# View live logs (Logstash)
docker-compose logs -f logstash

# Check Elasticsearch health
curl -u elastic:changeme http://localhost:9200/_cluster/health?pretty

# List all indexes
curl -u elastic:changeme http://localhost:9200/_cat/indices

# Count documents in index
curl -u elastic:changeme http://localhost:9200/syslog-*/_count

# Delete old index (example)
curl -X DELETE -u elastic:changeme http://localhost:9200/syslog-2026.09.*

# Open Kibana
open http://localhost  # admin/admin123
```

---

## 📖 Summary

| Component | Role | Key Port | Security |
|-----------|------|----------|----------|
| **Logstash** | Ingest & process logs | 5000, 5001 | No auth (internal) |
| **Elasticsearch** | Store & index logs | 9200 | elastic/changeme |
| **Kibana** | Search & visualize | 5601 | Via Nginx auth |
| **Nginx** | Proxy & auth | 80 → 8080 | admin/admin123 |

**Flow:** Logs → Logstash → Elasticsearch → Kibana (via Nginx) → User

**Next Steps:**
1. Test with real container logs
2. Create custom Kibana dashboards
3. Set up automated alerts
4. Plan multi-node Elasticsearch for production
