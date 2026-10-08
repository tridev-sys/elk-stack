#!/bin/bash
# Quick test script for ELK stack on macOS

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║          ELK STACK - QUICK FUNCTIONALITY TEST              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Kibana Access
echo "✓ TEST 1: Kibana Authentication (expect 401 without auth)"
curl -s -w "\nStatus: %{http_code}\n" http://localhost/ | head -1

echo ""
echo "✓ TEST 2: Kibana with Auth (expect 302 or 200)"
curl -s -u admin:admin123 -w "\nStatus: %{http_code}\n" http://localhost/ | head -1

echo ""
echo "✓ TEST 3: Elasticsearch Health"
docker-compose exec -T elasticsearch curl -s -u elastic:changeme 'http://localhost:9200/_cluster/health?pretty' | jq '.status'

echo ""
echo "═════════════════════════════════════════════════════════════"
echo "🔵 SENDING TEST LOGS (3 messages)..."
echo "═════════════════════════════════════════════════════════════"

# Method 1: From Docker container (most reliable on macOS)
echo ""
echo "Message 1: Sending via Docker container..."
docker exec logstash bash -c 'echo "<34>Oct 8 14:40:00 server1: Test message 1" > /dev/udp/127.0.0.1/5000'
echo "✓ Sent"

echo ""
echo "Message 2: Sending via Docker container..."
docker exec logstash bash -c 'echo "<30>Oct 8 14:40:01 server2: Test message 2 - INFO level" > /dev/udp/127.0.0.1/5000'
echo "✓ Sent"

echo ""
echo "Message 3: Sending via Docker container..."
docker exec logstash bash -c 'echo "<35>Oct 8 14:40:02 server3: Test message 3 - CRITICAL" > /dev/udp/127.0.0.1/5000'
echo "✓ Sent"

echo ""
echo "Waiting 3 seconds for processing..."
sleep 3

echo ""
echo "═════════════════════════════════════════════════════════════"
echo "✓ TEST 4: Verify Documents in Elasticsearch"
echo "═════════════════════════════════════════════════════════════"

# Count documents
COUNT=$(docker-compose exec -T elasticsearch curl -s -u elastic:changeme 'http://localhost:9200/_all/_count' 2>/dev/null | jq '.count')
echo "Total documents indexed: $COUNT"

echo ""
echo "✓ TEST 5: List Indices"
docker-compose exec -T elasticsearch curl -s -u elastic:changeme 'http://localhost:9200/_cat/indices?v' 2>/dev/null

echo ""
echo "═════════════════════════════════════════════════════════════"
echo "✅ ELK STACK VERIFICATION COMPLETE"
echo "═════════════════════════════════════════════════════════════"
echo ""
echo "📊 Next Steps:"
echo "   1. Open Kibana: open http://localhost"
echo "   2. Login: admin / admin123"
echo "   3. Go to: Management → Index Patterns → Create pattern 'syslog-*'"
echo "   4. Click: Discover → See your test logs"
echo ""
echo "🔍 View Raw Document:"
echo "   curl -u elastic:changeme 'http://localhost:9200/syslog-*/_search' | jq '.hits.hits[0]'"
echo ""
