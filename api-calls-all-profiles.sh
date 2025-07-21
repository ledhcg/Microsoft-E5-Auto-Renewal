#!/bin/bash

# Microsoft E5 Auto Renewal - Call All Profiles
# This script calls the API to run all configured profiles simultaneously

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Configuration
SERVER_URL="http://127.0.0.1:${E5_WEB_APP_PORT:-9999}"
PASSWORD="${E5_WEB_APP_PASSWORD}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Check if password is set
if [ -z "$PASSWORD" ]; then
    print_error "E5_WEB_APP_PASSWORD is not set in .env file"
    exit 1
fi

print_status "Starting Microsoft E5 Auto Renewal for all profiles..."
print_status "Server URL: $SERVER_URL"

# First, check available profiles
print_status "Checking available profiles..."
PROFILES_RESPONSE=$(curl -s "$SERVER_URL/profiles?password=$PASSWORD")

if [ $? -ne 0 ]; then
    print_error "Failed to connect to server. Make sure the server is running."
    exit 1
fi

# Parse profiles count
PROFILES_COUNT=$(echo "$PROFILES_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('total_count', 0))" 2>/dev/null)

if [ -z "$PROFILES_COUNT" ] || [ "$PROFILES_COUNT" -eq 0 ]; then
    print_error "No profiles found. Please add profiles using profile_manager.py"
    print_warning "Example: python3 profile_manager.py add profile1 <client_id> <client_secret> <refresh_token>"
    exit 1
fi

print_success "Found $PROFILES_COUNT enabled profile(s)"
echo ""

# Step 1: GET / - Server statistics
print_status "Step 1: Getting server statistics..."
STATS_RESPONSE=$(curl -s "$SERVER_URL/")
if [ $? -eq 0 ] && [ -n "$STATS_RESPONSE" ]; then
    echo "$STATS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$STATS_RESPONSE"
else
    print_error "Failed to get server statistics"
fi
echo ""

# Step 2: POST /call-all-profiles - Call APIs for all profiles
print_status "Step 2: Calling Microsoft APIs for all profiles..."
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"password\": \"$PASSWORD\"
    }" \
    "$SERVER_URL/call-all-profiles")

if [ $? -eq 0 ]; then
    # Parse and display response
    if echo "$RESPONSE" | python3 -m json.tool >/dev/null 2>&1; then
        echo "$RESPONSE" | python3 -m json.tool
        
        # Extract important info
        MESSAGE=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('message', 'Unknown response'))" 2>/dev/null)
        BATCH_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('batch_id', 'N/A'))" 2>/dev/null)
        PROFILES_COUNT=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('profiles_count', 0))" 2>/dev/null)
        
        print_success "$MESSAGE"
        print_status "Batch ID: $BATCH_ID"
        print_status "Profiles processed: $PROFILES_COUNT"
    else
        print_error "Response is not valid JSON:"
        echo "$RESPONSE"
        exit 1
    fi
else
    print_error "Failed to call API. Server might be down or password is incorrect."
    exit 1
fi
echo ""

# Step 3: GET /status - Wait until all tasks complete
print_status "Step 3: Monitoring all profile tasks execution..."
TASK_CHECK_COUNT=0
while true; do
    TASK_CHECK_COUNT=$((TASK_CHECK_COUNT + 1))
    STATUS_RESPONSE=$(curl -s "$SERVER_URL/status?password=$PASSWORD")
    if [ $? -eq 0 ] && echo "$STATUS_RESPONSE" | python3 -m json.tool >/dev/null 2>&1; then
        print_status "--- Task Status Check #$TASK_CHECK_COUNT ---"
        echo "$STATUS_RESPONSE" | python3 -m json.tool
        
        # Extract detailed information
        IS_BUSY=$(echo "$STATUS_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('is_busy', 'false'))" 2>/dev/null)
        RUNNING_TASKS=$(echo "$STATUS_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('running_tasks', 0))" 2>/dev/null)
        
        # Display task history details
        TASK_HISTORY=$(echo "$STATUS_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
history = data.get('task_history', [])
if history:
    print('\n📋 Task History Details:')
    for i, task in enumerate(history[-5:], 1):  # Show last 5 tasks
        print(f'  {i}. Task ID: {task.get(\"task_id\", \"N/A\")} | Status: {task.get(\"status\", \"N/A\")} | Time: {task.get(\"timestamp\", \"N/A\")}')
    
    # Check for incomplete tasks (started but not completed/failed)
    incomplete_tasks = []
    task_ids = set()
    for task in history:
        task_id = task.get('task_id')
        status = task.get('status')
        if task_id and status == 'started':
            has_completion = any(t.get('task_id') == task_id and t.get('status') in ['completed', 'failed'] for t in history)
            if not has_completion:
                incomplete_tasks.append(task_id)
    
    if incomplete_tasks:
        print(f'⚠️  Found {len(incomplete_tasks)} incomplete task(s): {", ".join(incomplete_tasks)}')
else:
    print('\n📋 No task history available')
" 2>/dev/null)
        
        if [ -n "$TASK_HISTORY" ]; then
            echo "$TASK_HISTORY"
        fi
        
        # Check for incomplete tasks
        INCOMPLETE_COUNT=$(echo "$STATUS_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    history = data.get('task_history', [])
    incomplete_tasks = []
    for task in history:
        task_id = task.get('task_id')
        status = task.get('status')
        if task_id and status == 'started':
            has_completion = any(t.get('task_id') == task_id and t.get('status') in ['completed', 'failed'] for t in history)
            if not has_completion:
                incomplete_tasks.append(task_id)
    print(len(incomplete_tasks))
except:
    print(0)
" 2>/dev/null || echo 0)
        
        if [ "$IS_BUSY" = "true" ] || [ "$INCOMPLETE_COUNT" -gt 0 ]; then
            if [ "$IS_BUSY" = "true" ]; then
                print_warning "⚠️  Server is BUSY - $RUNNING_TASKS task(s) still running. Waiting..."
            fi
            if [ "$INCOMPLETE_COUNT" -gt 0 ]; then
                print_warning "⚠️  Found $INCOMPLETE_COUNT incomplete task(s) in history. Waiting..."
            fi
            print_status "Checking again in 5 seconds..."
            sleep 5
        else
            print_success "✅ Server is FREE - All profile tasks completed successfully!"
            print_status "Total status checks performed: $TASK_CHECK_COUNT"
            break
        fi
    else
        print_error "Failed to get status or invalid response:"
        echo "$STATUS_RESPONSE"
        break
    fi
done
echo ""

# Step 4: GET /logs - Get full logs
print_status "Step 4: Getting full execution logs..."
LOG_RESPONSE=$(curl -s "$SERVER_URL/logs?password=$PASSWORD")
if [ $? -eq 0 ] && [ -n "$LOG_RESPONSE" ]; then
    echo "$LOG_RESPONSE"
else
    print_error "Failed to get logs or empty response"
fi
echo ""

print_success "All profiles renewal process completed successfully!"
print_status "Check the logs above for detailed execution results for each profile."