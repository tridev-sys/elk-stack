# Complete ELK Learning Guide

Learn ELK from zero to proficient. This guide assumes no prior knowledge.

---

## Table of Contents

1. [The Problem ELK Solves](#the-problem-elk-solves)
2. [Core Concepts](#core-concepts)
3. [Component Deep Dive](#component-deep-dive)
4. [Data Flow Step-by-Step](#data-flow-step-by-step)
5. [Hands-On Exercises](#hands-on-exercises)
6. [Real-World Scenarios](#real-world-scenarios)
7. [Advanced Topics](#advanced-topics)

---

## The Problem ELK Solves

### Before ELK: The Pain 😫

Imagine you run 50 Docker containers in production. Each container generates logs.

**Problems:**
```
Container 1  →  app.log  (inside container)
Container 2  →  app.log  (inside container)
Container 3  →  app.log  (inside container)
...
Container 50 →  app.log  (inside container)

Now:
- Container crashes. Where's the log? Lost forever (no persistent storage)
- Debug error: Which container? Check all 50? Manually SSH into each?
- Performance issue: Analyze 50 log files separately?
- Security audit: Find failed logins. Manual search through 50 files?
- Real-time monitoring: Impossible. Need to check logs after problems occur
```

**Workflow without ELK:**
```
Problem occurs
    ↓
SSH into server
    ↓
grep through logs manually
    ↓
Still can't find root cause
    ↓
Hours wasted 😤
```

### After ELK: The Solution ✨

```
Container 1  ┐
Container 2  ├─→  Logstash (collect & parse)  →  Elasticsearch (store & index)  →  Kibana (search & visualize)
Container 50 ┘

Now:
- All logs in ONE place
- Full-text search (find "error" in 50M logs in <100ms)
- Real-time dashboard showing errors as they happen
- Correlation: Find which container caused which error
- Historical analysis: What happened last week?
- Alerts: "If >100 errors/min, notify ops team"
```

**Workflow with ELK:**
```
Problem occurs
    ↓
Open Kibana dashboard (already running)
    ↓
Search: "error" AND "database"
    ↓
See all related logs with context
    ↓
Root cause identified in seconds ✅
```

---

## Core Concepts

### 1. What is a "Log"?

A log is **a record of something that happened** in your system.

**Examples:**

```log
[2026-10-08T14:30:45.123Z] INFO - User 'alice' logged in from 192.168.1.100
[2026-10-08T14:30:46.456Z] ERROR - Database connection timeout after 5s, retrying...
[2026-10-08T14:30:47.789Z] DEBUG - Executing query: SELECT * FROM users WHERE id=123
[2026-10-08T14:30:48.012Z] WARN - Response time 2500ms (threshold: 1000ms)
```

**Components of a log:**
- **Timestamp**: When it happened
- **Level**: How serious (DEBUG, INFO, WARN, ERROR, FATAL)
- **Source**: Where it came from (container, service, file)
- **Message**: What happened
- **Context**: User ID, transaction ID, etc.

### 2. What is "Indexing"?

Indexing is **creating a searchable lookup table** for your logs.

**Without Index (slow):**
```
Search: "error" in 1 million logs
→ Computer reads line 1: "this is a warning"
→ Check line 2: "database started"
→ Check line 3: "error: connection timeout"  ← Found!
→ Check lines 4-1,000,000: (continue searching)
Time: Several seconds
```

**With Index (fast):**
```
Index contains:
  "error" → [line 3, line 47, line 203, ...]
  "database" → [line 2, line 8, line 154, ...]
  "connection" → [line 3, line 5, line 99, ...]

Search: "error"
→ Lookup "error" in index
→ Instantly get: [line 3, line 47, line 203, ...]
Time: <100 milliseconds
```

### 3. What is a "Document"?

A document is **one log entry stored as JSON**.

```json
{
  "@timestamp": "2026-10-08T14:30:45.123Z",
  "level": "ERROR",
  "service": "api-gateway",
  "message": "Database connection timeout",
  "container": "api-prod-1",
  "user_id": 123,
  "response_time_ms": 2500,
  "retry_count": 2
}
```

Elasticsearch stores this as ONE searchable document.

### 4. What is an "Index"?

An index is **a collection of related documents** (like a database table).

```
Index: "syslog-2026.10.08"
├── Document 1: {timestamp: "14:30:45", message: "App started", ...}
├── Document 2: {timestamp: "14:30:46", message: "Error occurred", ...}
├── Document 3: {timestamp: "14:30:47", message: "Retry attempt", ...}
└── ... 1 million more documents
```

**Why daily indexes?**
```
syslog-2026.10.01  → 50M documents
syslog-2026.10.02  → 50M documents
syslog-2026.10.03  → 50M documents
...
syslog-2026.10.31  → 50M documents

Benefits:
- Delete old logs easily: `DELETE syslog-2026.09.*`
- Faster searches: Query only "syslog-2026.10.08" instead of all 310M docs
- Maintenance: Rebuild index for one day without affecting others
```

### 5. What is a "Query"?

A query is **a question you ask your data**.

```
Simple query:
  "Find all ERROR logs in last 24 hours"

Complex query:
  "Find ERROR logs from service 'api-gateway' 
   with response_time > 5000ms 
   in the last 7 days, 
   grouped by container"
```

Elasticsearch returns matching documents instantly.

---

## Component Deep Dive

### LOGSTASH: The Data Collector & Processor

**What it does:** Receives logs, transforms them, sends them somewhere.

**Analogy:** Mail sorting facility
```
Raw mail comes in (logs)
    ↓
Postal worker reads address (Logstash filter)
    ↓
Sorts by zip code (add metadata)
    ↓
Sends to destination (output to Elasticsearch)
```

#### Logstash Architecture

```
INPUT (Source) → FILTER (Process) → OUTPUT (Destination)
```

**1. INPUT: Where logs come from**

Your config:
```conf
input {
  syslog {
    port => 5000      # Listen on port 5000
    type => "syslog"  # Tag as syslog type
  }
  
  tcp {
    port => 5001      # Listen on port 5001
    type => "docker"  # Tag as docker type
    codec => "json"   # Expect JSON format
  }
}
```

**What happens:**
- Port 5000 receives: `<34>Oct 8 14:30:45 myapp: error occurred`
- Port 5001 receives: `{"level":"error","message":"occurred"}`

**2. FILTER: Transform the data**

Your config:
```conf
filter {
  if [type] == "docker" {
    mutate {
      add_field => { "[@metadata][index_name]" => "docker-%{+YYYY.MM.dd}" }
    }
  }
  
  if [type] == "syslog" {
    mutate {
      add_field => { "[@metadata][index_name]" => "syslog-%{+YYYY.MM.dd}" }
    }
  }
}
```

**What this does:**
```
Input from port 5000 (syslog):
{
  "message": "error occurred",
  "type": "syslog"
}
    ↓
Filter checks: if type == "syslog"?  YES
    ↓
Filter adds metadata:
{
  "message": "error occurred",
  "type": "syslog",
  "@metadata": {
    "index_name": "syslog-2026.10.08"  ← Added by filter!
  }
}
    ↓
This tells Elasticsearch which index to store it in
```

**3. OUTPUT: Send the transformed data**

Your config:
```conf
output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "%{[@metadata][index_name]}"  # Use metadata index name
    user => "elastic"
    password => "changeme"
  }
  
  stdout {
    codec => rubydebug  # Also print to console for debugging
  }
}
```

**What happens:**
```
Processed document:
{
  "message": "error occurred",
  "type": "syslog",
  "@timestamp": "2026-10-08T14:30:45.000Z",  # Auto-added
  "@metadata": { "index_name": "syslog-2026.10.08" }
}
    ↓
Send to Elasticsearch HTTP API:
  POST http://elasticsearch:9200/syslog-2026.10.08/_doc
  Body: { "message": "error occurred", ... }
    ↓
Elasticsearch receives and stores in syslog-2026.10.08 index
```

#### Real Example: Syslog Message Processing

**Input (raw syslog):**
```
<34>Oct  8 14:35:00 testhost: Database connection timeout after 30s
```

**After Logstash processing:**
```json
{
  "@timestamp": "2026-10-08T14:35:00.000Z",
  "@version": "1",
  "message": "Database connection timeout after 30s",
  "host": {
    "name": "testhost",
    "ip": "127.0.0.1"
  },
  "type": "syslog",
  "process": {
    "name": "testhost"
  },
  "log": {
    "syslog": {
      "priority": 34,
      "severity": {
        "code": 2,
        "name": "Critical"
      },
      "facility": {
        "code": 4,
        "name": "security/authorization"
      }
    }
  },
  "@metadata": {
    "index_name": "syslog-2026.10.08"
  }
}
```

**Notice:**
- Syslog format decoded into fields
- Timestamp extracted and standardized
- Severity level (Critical) identified
- Facility categorized
- All searchable fields created

---

### ELASTICSEARCH: The Storage & Search Engine

**What it does:** Stores documents, creates indexes, answers search queries.

**Analogy:** Library
```
Librarian (Elasticsearch) receives books (documents)
    ↓
Creates catalog (inverted index)
    ↓
You search for a topic → Librarian finds matching books instantly
```

#### How Elasticsearch Stores Data

```
Index: "syslog-2026.10.08"
│
├─ Settings (How to index)
│  ├─ Number of shards: 1
│  ├─ Replicas: 0
│  └─ Refresh interval: 1s
│
├─ Mappings (Field definitions)
│  ├─ message: type=text (searchable)
│  ├─ host.name: type=keyword (exact match)
│  ├─ @timestamp: type=date
│  ├─ level: type=keyword
│  └─ [20+ other fields...]
│
└─ Documents (Actual data)
   ├─ Doc 1: {"@timestamp": "14:35:00", "message": "error...", ...}
   ├─ Doc 2: {"@timestamp": "14:35:01", "message": "warning...", ...}
   ├─ Doc 3: {"@timestamp": "14:35:02", "message": "error...", ...}
   └─ ... 999,997 more documents
```

#### Text Fields vs Keyword Fields

**Text Field (Analyzed):**
```
Input: "The database connection failed"
    ↓
Analyzer breaks it down:
  ["the", "database", "connection", "failed"]
    ↓
Creates inverted index:
  "the" → [doc1, doc5, doc23, ...]
  "database" → [doc1, doc8, doc99, ...]
  "connection" → [doc1, doc3, doc12, ...]
  "failed" → [doc1, doc15, doc45, ...]
    ↓
Search "database connection" → Instant match!
```

**Keyword Field (Not Analyzed):**
```
Input: "error-2026-10-08"
    ↓
Stored exactly as-is:
  "error-2026-10-08" → [doc1, doc2, ...]
    ↓
Search "error-2026" → NO match (searching for partial string)
Search "error-2026-10-08" → MATCH (exact string)
```

#### Example: Searching in Elasticsearch

```bash
# Simple search: Find all documents with "error"
curl -X GET "elasticsearch:9200/syslog-*/_search" -H 'Content-Type: application/json' -d'
{
  "query": {
    "match": {
      "message": "error"
    }
  }
}'

Response: Found 1,523 documents in 45ms ✓

# Complex search: Errors from api-gateway in last 24 hours
curl -X GET "elasticsearch:9200/syslog-*/_search" -H 'Content-Type: application/json' -d'
{
  "query": {
    "bool": {
      "must": [
        {"match": {"message": "error"}},
        {"term": {"service": "api-gateway"}},
        {"range": {"@timestamp": {"gte": "now-24h"}}}
      ]
    }
  }
}'

Response: Found 127 documents in 38ms ✓
```

---

### KIBANA: The Data Visualization & Analysis Tool

**What it does:** Provides web UI to search logs and create dashboards.

**Analogy:** Web browser for your logs
```
Elasticsearch has the data (like a database)
    ↓
Kibana visualizes it (like a web UI)
    ↓
You get insights (like reading a website)
```

#### Kibana Features

**1. Discover: Raw Log Search**

```
You: Search for "database" AND "timeout"
    ↓
Kibana queries Elasticsearch
    ↓
Shows:
- Timeline (graph of matches over time)
- Table of matching logs
- Each log with expandable details
```

**Example screen:**
```
┌─────────────────────────────────────────────┐
│ Search: message:"database" AND message:"timeout"
├─────────────────────────────────────────────┤
│ Timeline:                                   │
│   10  ┃                                     │
│   8   ┃    ┃                                │
│   6   ┃ ┃  ┃  ┃                             │
│   4   ┃ ┃  ┃  ┃                             │
│   2   ┃ ┃  ┃  ┃  ┃                          │
│   0   ┗━━━━━━━━━━━ (time)                   │
│     14:30  14:35  14:40                     │
├─────────────────────────────────────────────┤
│ Results: 47 documents                       │
├─────────────────────────────────────────────┤
│ [2026-10-08T14:35:20]                       │
│ ERROR: Database connection timeout (30s)    │
│ Service: api-gateway, Container: api-1     │
│                                             │
│ [2026-10-08T14:35:25]                       │
│ WARN: Retrying database connection...       │
│ Service: api-gateway, Container: api-2     │
└─────────────────────────────────────────────┘
```

**2. Visualize: Create Charts**

```
Line Chart: Error count over time
  ↓
  Shows when errors spiked (e.g., 2pm had 10x more errors)

Pie Chart: Errors by service
  ↓
  Shows api-gateway: 60%, database: 30%, cache: 10%

Bar Chart: Response time by endpoint
  ↓
  Shows /users endpoint is slow (2500ms avg)
```

**3. Dashboards: Combine Visualizations**

```
Dashboard: "Production Status"
├─ Chart 1: Error rate (last 24h)
├─ Chart 2: Errors by service
├─ Chart 3: Top 10 error messages
├─ Chart 4: Failed logins over time
├─ Chart 5: Response time trend
└─ Chart 6: Disk usage by container
```

You open dashboard every morning to see system health.

---

### NGINX: The Authentication & Reverse Proxy

**What it does:** Sits in front of Kibana, protects it with password.

**Without Nginx:**
```
Anyone on network:
  curl http://kibana:5601
  → See all logs, delete data, etc.
  → SECURITY DISASTER! 😱
```

**With Nginx:**
```
Anyone on network:
  curl http://localhost
  → Nginx asks: "Password?"
  → Without password → 401 Unauthorized ❌
  → With password (admin/admin123) → Forward to Kibana ✓
```

**Request flow:**
```
Client Browser
  ↓ (http://localhost:80)
Nginx (Port 80)
  ├─ Check: Auth header present?
  │  ├─ NO → Return 401 + "enter password"
  │  └─ YES → Validate credentials
  │     ├─ Invalid → Return 401
  │     └─ Valid → Continue
  ├─ Forward request to Kibana:5601
  │  (add X-Forwarded-For, etc.)
  ↓
Kibana (Port 5601 - internal)
  ↓
Response (HTML page)
  ↓
Return to browser
```

---

## Data Flow Step-by-Step

### Complete Journey of ONE Log Entry

Let's follow a log from creation to viewing in Kibana.

**T=0:00s | Log Generated**

Your app crashes and prints:
```
2026-10-08T14:35:00Z [ERROR] Database connection failed after 30s
```

**T=0.01s | Log Sent to Logstash**

Your app sends via syslog protocol:
```
<34>Oct 8 14:35:00 myserver: Database connection failed after 30s
```

Network path:
```
App container (localhost:xxxx)
    ↓ (UDP packet)
Logstash container (port 5000)
```

**T=0.02s | Logstash Receives**

Logstash INPUT received the syslog message:
```
<34>Oct 8 14:35:00 myserver: Database connection failed after 30s
```

**T=0.05s | Logstash Parses**

Logstash FILTER processes it:
```
Input:
  Raw string: "<34>Oct 8 14:35:00 myserver: Database connection failed after 30s"

Parsing:
  Priority: 34
  ├─ Severity: 2 (Critical)
  └─ Facility: 4 (security/authorization)
  
  Timestamp: Oct 8 14:35:00
  
  Hostname: myserver
  
  Message: "Database connection failed after 30s"

Output document:
{
  "@timestamp": "2026-10-08T14:35:00.000Z",
  "message": "Database connection failed after 30s",
  "host": {"name": "myserver", "ip": "127.0.0.1"},
  "log": {
    "syslog": {
      "priority": 34,
      "severity": {"code": 2, "name": "Critical"},
      "facility": {"code": 4, "name": "security"}
    }
  },
  "@metadata": {"index_name": "syslog-2026.10.08"}
}
```

**T=0.10s | Logstash Sends to Elasticsearch**

Logstash OUTPUT sends HTTP request:
```bash
POST http://elasticsearch:9200/syslog-2026.10.08/_doc HTTP/1.1
Content-Type: application/json

{
  "@timestamp": "2026-10-08T14:35:00.000Z",
  "message": "Database connection failed after 30s",
  ...
}
```

Network path:
```
Logstash container (elasticsearch:9200)
    ↓ (HTTP POST)
Elasticsearch container (port 9200)
```

**T=0.15s | Elasticsearch Indexes**

Elasticsearch receives document:

```
1. Validates format
2. Analyzes fields:
   - message: "Database connection failed after 30s"
     → Creates index terms: ["database", "connection", "failed", ...]
   - @timestamp: "2026-10-08T14:35:00.000Z"
     → Indexed as date
3. Adds to inverted index:
   "database" → [doc_id_1, ...]
   "connection" → [doc_id_1, ...]
   "failed" → [doc_id_1, ...]
   "critical" → [doc_id_1, ...]
4. Stores document in syslog-2026.10.08 index
5. Returns: {"_id": "abc123", "_index": "syslog-2026.10.08"}
```

**T=0.20s | Kibana Ready to Search**

Elasticsearch is ready. The document is searchable.

Kibana can now query it:
```bash
curl -u elastic:changeme http://elasticsearch:9200/syslog-2026.10.08/_search -d'
{
  "query": {"match": {"message": "database"}}
}'

Response:
{
  "hits": {
    "total": {"value": 1},
    "hits": [
      {
        "_id": "abc123",
        "_source": {
          "@timestamp": "2026-10-08T14:35:00.000Z",
          "message": "Database connection failed after 30s",
          ...
        }
      }
    ]
  }
}
```

**T=0.50s | You Open Kibana (30 seconds later)**

You notice something is wrong and open Kibana:
```
1. Browser: GET http://localhost (port 80)
2. Nginx: Asks for password
3. You enter: admin / admin123
4. Nginx: Forwards to Kibana:5601
5. Kibana UI loads
```

**T=0.55s | You Search**

You type in Kibana search:
```
message:"database" AND severity:"Critical"
```

Kibana queries Elasticsearch:
```bash
POST /syslog-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"match": {"message": "database"}},
        {"term": {"log.syslog.severity.name": "Critical"}}
      ]
    }
  }
}
```

**T=0.60s | Results**

Kibana displays:
```
Results: 1 document found in 10ms

[2026-10-08 14:35:00.000]
ERROR: Database connection failed after 30s
Host: myserver
Severity: Critical
```

**T=0.61s | Root Cause Found ✓**

You see the error, check your database, discover it crashed at exactly 14:35:00.

**Restart database.**

**Crisis averted!** Total time: 61 seconds from error to fix.

---

## Hands-On Exercises

### Exercise 1: Send Your First Log

**Objective:** Get comfortable sending logs to Logstash.

```bash
# Method 1: From inside Docker (most reliable)
docker exec logstash bash -c 'echo "<34>Oct 8 test: Hello from ELK" > /dev/udp/127.0.0.1/5000'

# Verify it was indexed
curl -u elastic:changeme 'http://localhost:9200/syslog-*/_count'
# Should show: {"count": 1}
```

**What you learned:**
- How to send a syslog message
- How to verify it reached Elasticsearch
- Syslog priority code <34> means Critical

---

### Exercise 2: Search Logs Programmatically

**Objective:** Learn Elasticsearch query syntax.

```bash
# Search for all "error" messages
curl -u elastic:changeme 'http://localhost:9200/syslog-*/_search?q=message:error'

# Pretty print result
curl -u elastic:changeme 'http://localhost:9200/syslog-*/_search' -H 'Content-Type: application/json' -d'
{
  "query": {
    "match": {
      "message": "error"
    }
  }
}' | jq '.hits.hits[0]._source'
```

**What you learned:**
- How to query Elasticsearch directly
- JSON query syntax
- How to parse results with jq

---

### Exercise 3: Create Custom Fields

**Objective:** Understand how to add structured data.

Modify `config/logstash/logstash.conf`:

```conf
filter {
  if [type] == "syslog" {
    mutate {
      add_field => { 
        "[@metadata][index_name]" => "syslog-%{+YYYY.MM.dd}"
        "environment" => "production"
        "team" => "platform"
      }
    }
  }
}
```

Restart Logstash:
```bash
docker-compose restart logstash
```

Send new log:
```bash
docker exec logstash bash -c 'echo "<34>Oct 8 test: New message" > /dev/udp/127.0.0.1/5000'
```

View in Elasticsearch:
```bash
curl -u elastic:changeme 'http://localhost:9200/syslog-*/_search' | jq '.hits.hits[0]._source | {message, environment, team}'
```

**Output:**
```json
{
  "message": "New message",
  "environment": "production",
  "team": "platform"
}
```

**What you learned:**
- How to add custom fields in Logstash
- Fields are now searchable
- Can filter by: `environment:production AND team:platform`

---

### Exercise 4: Use Kibana UI

**Objective:** Learn Kibana interface.

1. **Open Kibana:**
   ```bash
   open http://localhost
   # Login: admin / admin123
   ```

2. **Create Index Pattern:**
   - Go to: Menu → Stack Management → Index Patterns
   - Click: Create Index Pattern
   - Pattern: `syslog-*`
   - Timestamp field: `@timestamp`
   - Create Pattern ✓

3. **Discover Logs:**
   - Go to: Analytics → Discover
   - Select index: `syslog-*`
   - See all your logs
   - Click on one to expand
   - Scroll down to see all fields

4. **Search:**
   - Type in search: `message:error`
   - Hit Enter
   - See filtered results

5. **Filter:**
   - Click on field name: `log.syslog.severity.name`
   - Click on value: `Critical`
   - Only Critical logs shown

**What you learned:**
- Kibana interface basics
- How to create index patterns
- How to search and filter
- How to inspect individual documents

---

### Exercise 5: Create a Visualization

**Objective:** Create your first chart.

1. **Open Kibana** → Menu → Analytics → Visualize

2. **Create Visualization:**
   - Click: Create Visualization
   - Type: Line Chart
   - Index: syslog-*
   - Click: Next

3. **Configure:**
   - X-axis: `@timestamp` (Date)
   - Y-axis: `Count`
   - Click: Update

4. **Result:**
   - You see a line chart showing log volume over time
   - Peaks and valleys = when your system generated more logs

**What you learned:**
- Creating visualizations from raw data
- How to chart trends over time
- How to visualize patterns

---

## Real-World Scenarios

### Scenario 1: Finding Failed Logins

**Situation:** Your security team wants to find all failed login attempts in the last 7 days.

**Without ELK:** Check 7 days of logs on 50 servers = impossible

**With ELK:**

```bash
# Search for failed logins
curl -u elastic:changeme 'http://localhost:9200/syslog-*/_search' -d'
{
  "query": {
    "bool": {
      "must": [
        {"match": {"message": "login"}},
        {"match": {"message": "failed"}},
        {"range": {"@timestamp": {"gte": "now-7d"}}}
      ]
    }
  }
}' | jq '.hits | {total: .total.value, hits: .hits[].\_source | {timestamp, message}}'

Result:
{
  "total": 42,
  "hits": [
    {"timestamp": "2026-10-01T03:22:00Z", "message": "Failed login from 192.168.1.100"},
    {"timestamp": "2026-10-01T03:25:00Z", "message": "Failed login from 192.168.1.100"},
    {"timestamp": "2026-10-01T03:28:00Z", "message": "Failed login from 192.168.1.100"},
    ...
  ]
}
```

**Finding:** Same IP (192.168.1.100) failed 42 times in 7 days = potential attack!

**Action:** Block IP, increase security, investigate server.

---

### Scenario 2: Performance Debugging

**Situation:** API endpoint is slow for some users.

**With ELK:**

```bash
# Find slow requests
curl -u elastic:changeme 'http://localhost:9200/app-logs-*/_search' -d'
{
  "query": {
    "range": {
      "response_time_ms": {"gte": 2000}
    }
  }
}' | jq '.hits.hits[] | {endpoint: ._source.endpoint, time_ms: ._source.response_time_ms, user: ._source.user_id}'

Result:
[
  {endpoint: "/api/users", time_ms: 2500, user: 123},
  {endpoint: "/api/users", time_ms: 2800, user: 456},
  {endpoint: "/api/users", time_ms: 3100, user: 789},
  {endpoint: "/api/orders", time_ms: 5200, user: 123}
]
```

**Finding:** `/api/users` endpoint is slow for multiple users

**Investigation:**
- Check logs for that endpoint
- Find database query running long
- Optimize query
- Redeploy

**Verification:**
- Search same endpoint next day
- Response time now <500ms ✓

---

### Scenario 3: Error Spike Investigation

**Situation:** Error rate suddenly jumped from 1% to 10%

**Dashboard shows:**
```
┌─────────────────────────────────┐
│ Error Rate over Time            │
│                                 │
│ 10% ┃                    ▲      │
│  8% ┃                   ╱ ╲     │
│  6% ┃                  ╱   ╲    │
│  4% ┃                 ╱     ╲   │
│  2% ┃_________________╱_______╲_│
│  0% ┗━━━━━━━━━━━━━━━━━━━━━━━━│
│    14:30    14:35    14:40    │
│             ↑                  │
│           Spike!               │
└─────────────────────────────────┘
```

**Investigate:**

1. **What errors increased?**
   ```bash
   curl -u elastic:changeme 'http://localhost:9200/syslog-*/_search' -d'
   {
     "query": {"match": {"level": "ERROR"}},
     "size": 100
   }' | jq '.hits.hits[] | ._source.message' | sort | uniq -c | sort -rn

   Result:
   50 "Database connection timeout"
   30 "Timeout waiting for response"
   20 "Other errors"
   ```

2. **When did it start?**
   - Spike began at 14:35:22

3. **What happened at 14:35?**
   - Search deployment logs
   - Found: "New version v2.5.1 deployed at 14:35"

4. **Root cause:** New deployment broke database connection pooling

5. **Fix:** Rollback to v2.5.0 immediately

6. **Verify:** Errors drop back to 1% within 5 minutes

---

## Advanced Topics

### 1. Log Aggregation Patterns

**Pattern 1: Correlating Errors Across Services**

Microservices make it hard to debug:
```
User makes request
  ↓
Service A processes (generates log)
  ↓
Calls Service B (generates log in Service B)
  ↓
Calls Service C (generates log in Service C)
  ↓
Error in C (generates error log)
  ↓
Error bubbles up to A (generates error log)

Now: 3 separate logs describing ONE request
```

**Solution: Add Trace ID**

Every log includes `trace_id`:
```json
{
  "trace_id": "abc-123-def-456",
  "service": "service-a",
  "message": "Calling service-b"
}
```

Search: `trace_id:abc-123-def-456`

Result: All 3 logs from single request, showing full journey

**What you learned:** Correlation makes debugging across services possible

---

### 2. Alerting

**Without alerts:**
- You check dashboard manually at 9am
- System was down from 3am-8am
- Customers frustrated

**With alerts:**
```
Elasticsearch continuously monitors:

IF (error_count > 100 per minute) 
  THEN send alert to ops-team@company.com

3:15am: Error threshold exceeded
Ops team gets paged immediately
System recovered by 3:20am
Customers barely notice
```

(Kibana Alerting coming in future exercises)

---

### 3. Log Retention Policies

**Problem:** Elasticsearch stores ALL logs forever = expensive disk space

**Solution: Index Lifecycle Policy**

```
Day 1-7: Keep in "hot" tier (fast, searchable)
  → Users query recent logs frequently
  
Day 8-30: Move to "warm" tier (slower, cheaper)
  → Few people query 20-day-old logs
  
Day 31+: Delete
  → Rarely needed, save money
```

---

### 4. Parsing Complex Logs

**Your current filter:**
```conf
filter {
  if [type] == "syslog" {
    mutate {
      add_field => { "[@metadata][index_name]" => "syslog-%{+YYYY.MM.dd}" }
    }
  }
}
```

**Problem:** Each app has different log format

**Solution: Use GROK filter to parse**

```conf
filter {
  if [type] == "app" {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:timestamp} \[%{LOGLEVEL:level}\] %{GREEDYDATA:msg}"
      }
    }
    
    mutate {
      convert => { "timestamp" => "date" }
      add_field => { "[@metadata][index_name]" => "app-%{+YYYY.MM.dd}" }
    }
  }
}
```

**Input:** `2026-10-08T14:35:00.000Z [ERROR] Database error occurred`

**Output:**
```json
{
  "timestamp": "2026-10-08T14:35:00.000Z",
  "level": "ERROR",
  "msg": "Database error occurred"
}
```

Now each field is separately searchable!

---

## Summary: ELK Learning Path

```
Level 1: BASICS ✓ (You are here)
├─ What is logging?
├─ Basic architecture
├─ How data flows
└─ Using Kibana UI

Level 2: INTERMEDIATE
├─ Writing Logstash filters
├─ Complex queries
├─ Creating dashboards
└─ Performance tuning

Level 3: ADVANCED
├─ Multi-node Elasticsearch
├─ Alert rules
├─ Security (TLS, RBAC)
└─ Custom plugins

Level 4: EXPERT
├─ Machine learning
├─ Anomaly detection
├─ High-scale operations
└─ ELK architecture design
```

---

## Key Takeaways

1. **ELK solves the log management problem**
   - Single place to search all logs
   - Instant search (indexing)
   - Beautiful dashboards
   - Real-time alerts

2. **Three core components**
   - **Logstash:** Collect & process
   - **Elasticsearch:** Store & search
   - **Kibana:** Visualize & analyze

3. **The value of logging**
   - Debug production issues faster
   - Spot security threats
   - Understand system behavior
   - Prove SLA compliance

4. **Next step: Practice**
   - Send different log types
   - Create your own dashboards
   - Write Logstash filters
   - Search complex queries

---

## Cheat Sheet

```bash
# Send a test log (from Mac)
docker exec logstash bash -c 'echo "<34>Oct 8 test: message" > /dev/udp/127.0.0.1/5000'

# Count documents
curl -u elastic:changeme http://localhost:9200/_all/_count | jq '.count'

# List indexes
curl -u elastic:changeme http://localhost:9200/_cat/indices

# Search for term
curl -u elastic:changeme 'http://localhost:9200/syslog-*/_search?q=message:error'

# Delete old index
curl -X DELETE -u elastic:changeme http://localhost:9200/syslog-2026.09.*

# Open Kibana
open http://localhost

# View Elasticsearch health
curl -u elastic:changeme http://localhost:9200/_cluster/health?pretty

# Pretty print last document
curl -u elastic:changeme 'http://localhost:9200/syslog-*/_search' | jq '.hits.hits[0]._source'
```

---

**You've completed ELK fundamentals! 🎓**

Next: Build your own logging strategy and deploy to your applications!
