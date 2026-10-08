═══════════════════════════════════════════════════════════════════════════════
                        ELK STACK COMPLETE TESTING GUIDE
═══════════════════════════════════════════════════════════════════════════════

## QUICK TEST CHECKLIST

✅ 1. VERIFY SERVICES ARE RUNNING
────────────────────────────────────────────────────────────────────────────
cd /Users/tridevguha/Desktop/Projects/ELK
docker-compose ps
docker-compose -f proxy_server/docker-compose.yml ps

Expected: All services should show "Up" status (healthchecks may show "starting")


✅ 2. TEST KIBANA ACCESS (UNAUTHENTICATED - Should FAIL)
────────────────────────────────────────────────────────────────────────────
curl -v http://localhost/

Expected: HTTP 401 Unauthorized
Header: WWW-Authenticate: Basic realm="ELK Stack - Restricted Access"


✅ 3. TEST KIBANA ACCESS (WITH AUTHENTICATION - Should SUCCEED)
────────────────────────────────────────────────────────────────────────────
curl -u admin:admin123 http://localhost/

Expected: HTTP 302 redirect (or 200 with Kibana HTML)
Body: Kibana HTML content


✅ 4. VERIFY ELASTICSEARCH HEALTH
────────────────────────────────────────────────────────────────────────────
docker-compose exec -T elasticsearch curl -s -u elastic:changeme 'http://localhost:9200/_cluster/health' | jq .

Expected: "status": "green"
Look for: number_of_nodes: 1, active_shards: 18


✅ 5. VERIFY LOGSTASH CONNECTIVITY TO ELASTICSEARCH
────────────────────────────────────────────────────────────────────────────
docker-compose logs logstash | grep "Elasticsearch version determined"

Expected: Should show: "Elasticsearch version determined (8.9.1)"


✅ 6. SEND TEST SYSLOG MESSAGE
────────────────────────────────────────────────────────────────────────────
echo "<34>Oct  8 12:31:00 testhost: test log from ELK" | nc -w 1 localhost 5000

Expected: No error output (silent success)


✅ 7. SEND TEST JSON MESSAGE (via TCP port 5001)
────────────────────────────────────────────────────────────────────────────
echo '{"message":"test docker log","container":"myapp"}' | nc -w 1 localhost 5001

Expected: No error output (silent success)


✅ 8. WAIT & VERIFY INDEX CREATED
────────────────────────────────────────────────────────────────────────────
sleep 3
docker-compose exec -T elasticsearch curl -s -u elastic:changeme 'http://localhost:9200/_cat/indices?v'

Expected: Should see "syslog-2026.10.08" or "docker-2026.10.08" index


✅ 9. VERIFY LOGS IN ELASTICSEARCH
────────────────────────────────────────────────────────────────────────────
docker-compose exec -T elasticsearch curl -s -u elastic:changeme 'http://localhost:9200/syslog-*/_search' | jq '.hits.hits[0]'

Expected: JSON document with your test message


✅ 10. VIEW IN KIBANA UI
────────────────────────────────────────────────────────────────────────────
1. Open browser: http://localhost
2. Login: admin / admin123
3. Click "Discover" in left sidebar
4. Create index pattern: "syslog-*" or "docker-*"
5. Select timestamp field: "@timestamp"
6. View documents in the logs table


═══════════════════════════════════════════════════════════════════════════════
                              PORT REFERENCE
═══════════════════════════════════════════════════════════════════════════════

📍 Kibana Web UI
   - URL: http://localhost (port 80)
   - Auth: admin / admin123
   - Via: Nginx reverse proxy

📍 Elasticsearch API
   - URL: http://elasticsearch:9200 (internal only)
   - Auth: elastic / changeme
   - From: Kibana, Logstash

📍 Logstash Inputs
   - Syslog: port 5000 (UDP + TCP)
   - JSON/Docker: port 5001 (TCP)
   - Logs: docker-YYYY.MM.dd, syslog-YYYY.MM.dd indices

📍 Nginx Proxy
   - Upstream: Kibana 5601 → Nginx 8080 → Host 80
   - Auth: htpasswd (admin/admin123)

═══════════════════════════════════════════════════════════════════════════════
                            TROUBLESHOOTING
═══════════════════════════════════════════════════════════════════════════════

❌ Logstash shows "unhealthy"
   → Normal during startup (healthcheck takes 60s)
   → Check logs: docker-compose logs logstash
   → Wait 2-3 minutes for full startup

❌ No indices created after sending logs
   → Check Logstash logs: docker-compose logs logstash | tail -20
   → Verify Elasticsearch: docker-compose ps elasticsearch
   → Check connectivity: docker exec elasticsearch curl -s http://localhost:9200

❌ Cannot connect to Kibana
   → Check proxy is running: docker ps | grep proxy_server
   → Check port 80: lsof -i :80
   → Verify auth: curl -u admin:admin123 http://localhost/

❌ 502 Bad Gateway error
   → Check Kibana container: docker-compose ps kibana
   → Check shared network: docker network inspect shared
   → View proxy logs: docker logs proxy_server

═══════════════════════════════════════════════════════════════════════════════
