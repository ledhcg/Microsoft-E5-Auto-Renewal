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

echo "=== Microsoft E5 Task Status Checker ==="
echo "Time: $(date)"
echo ""

# Function to check task status
check_status() {
    echo "Checking task status..."
    STATUS_RESPONSE=$(curl -s "${BASE_URL}/status?password=${E5_WEB_APP_PASSWORD}")
    
    if echo "$STATUS_RESPONSE" | jq . >/dev/null 2>&1; then
        echo "$STATUS_RESPONSE" | jq .
        
        # Extract running tasks count
        RUNNING_TASKS=$(echo "$STATUS_RESPONSE" | jq -r '.running_tasks')
        IS_BUSY=$(echo "$STATUS_RESPONSE" | jq -r '.is_busy')
        
        echo ""
        if [ "$IS_BUSY" = "true" ]; then
            echo "⚠️  Server is BUSY - $RUNNING_TASKS task(s) running"
            return 1
        else
            echo "✅ Server is FREE - No tasks running"
            return 0
        fi
    else
        echo "❌ Failed to get status or invalid response:"
        echo "$STATUS_RESPONSE"
        return 1
    fi
}

# Function to wait for tasks to complete
wait_for_completion() {
    echo "Waiting for all tasks to complete..."
    
    while true; do
        check_status
        if [ $? -eq 0 ]; then
            echo "✅ All tasks completed!"
            break
        fi
        
        echo "⏳ Still waiting... (checking again in 5 seconds)"
        sleep 5
    done
}

# Function to create a new task and wait for completion
create_and_wait() {
    echo "1. Creating a new task..."
    TASK_RESPONSE=$(curl -s -X POST "${BASE_URL}/call" \
        -H "Content-Type: application/json" \
        -d "{
            \"password\": \"${E5_WEB_APP_PASSWORD}\",
            \"refresh_token\": \"${E5_REFRESH_TOKEN}\",
            \"client_id\": \"${E5_CLIENT_ID}\",
            \"client_secret\": \"${E5_CLIENT_SECRET}\"
        }")
    
    if echo "$TASK_RESPONSE" | jq . >/dev/null 2>&1; then
        echo "$TASK_RESPONSE" | jq .
        TASK_ID=$(echo "$TASK_RESPONSE" | jq -r '.task_id')
        echo "📝 Task created with ID: $TASK_ID"
    else
        echo "❌ Failed to create task:"
        echo "$TASK_RESPONSE"
        exit 1
    fi
    
    echo ""
    echo "2. Waiting for task completion..."
    wait_for_completion
}

# Main menu
echo "Choose an option:"
echo "1. Check current status only"
echo "2. Create task and wait for completion"
echo "3. Wait for current tasks to complete"
read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        check_status
        ;;
    2)
        create_and_wait
        ;;
    3)
        wait_for_completion
        ;;
    *)
        echo "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "=== Script completed ==="