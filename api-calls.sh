#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    source .env
else
    echo "Warning: .env file not found!"
    exit 1
fi

# API base URL
BASE_URL="http://localhost:${E5_WEB_APP_PORT:-9999}"

echo "=== Microsoft E5 Auto Renewal API Calls ==="
echo "Time: $(date)"
echo ""

# 1. GET / - Server statistics
echo "1. Getting server statistics..."
curl -s "${BASE_URL}/" | jq .
echo ""

# 2. POST /call - Call Microsoft APIs
echo "2. Calling Microsoft APIs..."
RESPONSE=$(curl -s -X POST "${BASE_URL}/call" \
    -H "Content-Type: application/json" \
    -d "{
        \"password\": \"${E5_WEB_APP_PASSWORD}\",
        \"refresh_token\": \"${E5_REFRESH_TOKEN}\",
        \"client_id\": \"${E5_CLIENT_ID}\",
        \"client_secret\": \"${E5_CLIENT_SECRET}\"
    }")

if echo "$RESPONSE" | jq . >/dev/null 2>&1; then
    echo "$RESPONSE" | jq .
else
    echo "Response is not valid JSON:"
    echo "$RESPONSE"
fi
echo ""

# 3. GET /status - Wait until server is free
echo "3. Waiting for server to be free..."
while true; do
    STATUS_RESPONSE=$(curl -s "${BASE_URL}/status?password=${E5_WEB_APP_PASSWORD}")
    if echo "$STATUS_RESPONSE" | jq . >/dev/null 2>&1; then
        echo "$STATUS_RESPONSE" | jq .
        
        # Check if server is busy
        IS_BUSY=$(echo "$STATUS_RESPONSE" | jq -r '.is_busy')
        RUNNING_TASKS=$(echo "$STATUS_RESPONSE" | jq -r '.running_tasks')
        
        if [ "$IS_BUSY" = "true" ]; then
            echo "⚠️  Server is BUSY - $RUNNING_TASKS task(s) running. Waiting..."
            sleep 5
        else
            echo "✅ Server is FREE - No tasks running"
            break
        fi
    else
        echo "Failed to get status or invalid response:"
        echo "$STATUS_RESPONSE"
        break
    fi
done
echo ""

# 4. GET /logs - Get full logs
echo "4. Getting full logs..."
LOG_RESPONSE=$(curl -s "${BASE_URL}/logs?password=${E5_WEB_APP_PASSWORD}")
if [ $? -eq 0 ] && [ -n "$LOG_RESPONSE" ]; then
    # Check if response contains HTML error (500 Internal Server Error)
    if echo "$LOG_RESPONSE" | grep -q "Internal Server Error"; then
        echo "⚠️  Log file not found on server (this is normal for first run)"
        echo "Server response: Log file 'event-log.txt' does not exist yet"
        echo "Logs will be available after the first successful API execution"
    else
        echo "$LOG_RESPONSE"
    fi
else
    echo "Failed to get logs or empty response"
fi
echo ""

