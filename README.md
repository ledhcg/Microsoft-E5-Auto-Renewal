<div align="center"><h1>Microsoft E5 Auto Renewal</h1>
<b>An open-source Python program made using <a href="https://github.com/pallets/quart">Quart</a> & <a href="https://github.com/encode/uvicorn">Uvicorn</a> for automatic renewal of Microsoft's Developer E5 subscription with multi-profile support.</b></div><br>

## **📑 INDEX**

* [**⚙️ Installation**](#installation)
  * [Python & Git](#i-1)
  * [Download](#i-2)
  * [Requirements](#i-3)
* [**📝 Variables**](#variables)
* [**🚀 Multi-Profile Support**](#multi-profile)
  * [Features](#mp-features)
  * [Configuration](#mp-config)
  * [API Endpoints](#mp-api)
  * [Shell Scripts](#mp-scripts)
* [**📊 Task Monitoring**](#task-monitoring)
  * [API Endpoints](#tm-api)
  * [Usage Examples](#tm-usage)
  * [Scripts](#tm-scripts)
* [**🔐 GitHub Secrets Setup**](#github-secrets)
  * [Security Configuration](#gs-config)
  * [Step-by-step Guide](#gs-steps)
* [**🕹 Deployment**](#deployment)
  * [Locally](#d-1)
  * [Docker](#d-2)
  * [GitHub Actions](#d-3)
* [**🌐 Routes**](#routes)
* [**🍎 Running on macOS**](#macos-guide)
* [**❤️ Credits & Thanks**](#credits)

<a name="installation"></a>

## ⚙️ Installation

<a name="i-1"></a>

**1.Install Python & Git:**

  * For Windows:

    ```
    winget install Python.Python.3.12
    winget install Git.Git
    ```

  * For Linux:

    ```
    sudo apt-get update && sudo apt-get install -y python3.12 git pip
    ```

  * For macOS:

    ```
    brew install python@3.12 git
    ```

  * For Termux:

    ```
    pkg install python -y
    pkg install git -y
    ```

<a name="i-2"></a>

**2.Download repository:**

  ```
  git clone https://github.com/ledhcg/Microsoft-E5-Auto-Renewal.git
  ```

**3.Change Directory:**

  ```
  cd Microsoft-E5-Auto-Renewal
  ```

<a name="i-3"></a>

**4.Install requirements:**

  ```
  pip install -r requirements.txt
  ```

<a name="variables"></a>

## 📝 Variables
**The variables provided below should either be completed within the config.py file or configured as environment variables.**
* `CLIENT_ID`|`E5_CLIENT_ID`: ID of your Azure Active Directory app. `str`
  * Create an app in [Azure Active Directory](https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps).
  * Choose application type as 'Web' & set Redirect URL to `http://localhost:53682/`.
  * Copy the Application (client) ID.
* `CLIENT_SECRET`|`E5_CLIENT_SECRET`: Secret of your Azure Active Directory app. `str`
  * In your  Azure Active Directory app overview, navigate to Client credentials and create secret.
* `REFRESH_TOKEN`|`E5_REFRESH_TOKEN`: Refresh token for your admin account. `str`
  * In CLI, run:

    ```
    python auth.py YourClientID YourClientSecret
    ```
  * Follow on-screen instructions.
  * From output, copy the value of `refresh_token` key.

> [!NOTE]
> All refresh tokens issued by the authorization client have a validity period of 90 days from the date of issue.

* `WEB_APP_PASSWORD`|`E5_WEB_APP_PASSWORD`: Strong password to protect critical routes of your web server. `str`
  * Keep it strong and don't share it.
* `WEB_APP_HOST`|`E5_WEB_APP_HOST`: Bind address of web server. `str`
  * By default `0.0.0.0` to run on all possible addresses.
* `WEB_APP_PORT`|`PORT`: Port for web server to listen to. `int`
  * By default `9999`.
* `TIME_DELAY`|`E5_TIME_DELAY`: Time (in seconds) to wait before calling another endpoint. `int`
  * By default 3 seconds.
* `UPLOAD_LOGS_TO_ONEDRIVE`|`E5_UPLOAD_LOGS_TO_ONEDRIVE`: Upload log files to OneDrive after task completion. `bool`
  * By default `true`. Set to `false` to disable OneDrive uploads.

<a name="multi-profile"></a>

## 🚀 Multi-Profile Support

<a name="mp-features"></a>

This system has been updated to support running multiple Microsoft E5 profiles simultaneously, each with separate authentication information.

### 🌟 New Features

- **Multi-profile support**: Run multiple E5 accounts simultaneously
- **Easy profile management**: Python scripts to add/remove/enable/disable profiles
- **New API**: Endpoint to call all profiles at once
- **Backward compatibility**: Still supports the old method with .env file

<a name="mp-config"></a>

### 📁 Configuration

#### profiles.json
File containing information for all profiles:
```json
{
  "profiles": [
    {
      "name": "profile1",
      "client_id": "your-client-id-1",
      "client_secret": "your-client-secret-1",
      "refresh_token": "your-refresh-token-1",
      "enabled": true
    },
    {
      "name": "profile2",
      "client_id": "your-client-id-2",
      "client_secret": "your-client-secret-2",
      "refresh_token": "your-refresh-token-2",
      "enabled": true
    }
  ]
}
```

#### Profile Management
You can manage profiles by directly editing the `profiles.json` file:

1. **Add new profile**: Open `profiles.json` file and add profile to `profiles` array
2. **Enable/disable profile**: Change `enabled` value to `true` or `false`
3. **Delete profile**: Remove profile object from array
4. **Save file**: Ensure correct JSON syntax and save file

#### Environment Variables
```env
# Server information
E5_WEB_APP_PASSWORD=your_password
E5_WEB_APP_HOST=0.0.0.0
E5_WEB_APP_PORT=9999
E5_TIME_DELAY=3

# Default profile (backward compatibility)
E5_CLIENT_ID=your_default_client_id
E5_CLIENT_SECRET=your_default_client_secret
E5_REFRESH_TOKEN=your_default_refresh_token
```

<a name="mp-api"></a>

### 🌐 New API Endpoints

#### 1. Call all profiles
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"password":"your_password"}' \
  "http://127.0.0.1:9999/call-all-profiles"
```

**Response:**
```json
{
  "message": "Success - 2 profile tasks created.",
  "batch_id": "abc12345",
  "task_ids": ["abc12345-profile1", "abc12345-profile2"],
  "profiles_count": 2
}
```

#### 2. View profile list
```bash
curl "http://127.0.0.1:9999/profiles?password=your_password"
```

**Response:**
```json
{
  "profiles": [
    {
      "name": "profile1",
      "client_id": "your-client-id...",
      "enabled": true
    }
  ],
  "total_count": 1
}
```

<a name="mp-scripts"></a>

### 🔧 Using Shell Scripts

#### Run all profiles
```bash
./api-calls-all-profiles.sh
```

This script will:
1. Check number of available profiles
2. Call API to run all profiles
3. Display results with colors

#### Run single profile (old method)
```bash
./api-calls.sh
```

### 🔄 Cron Job

#### Run all profiles periodically
```bash
# Run every 4 hours
0 */4 * * * cd /path/to/auto-e5 && ./api-calls-all-profiles.sh
```

#### Run specific profile
```bash
# Run default profile every 4 hours
0 */4 * * * cd /path/to/auto-e5 && ./api-calls.sh
```

<a name="task-monitoring"></a>

## 📊 Task Monitoring System

<a name="tm-api"></a>

This system allows you to monitor the status of tasks running on the Microsoft E5 Auto Renewal server. This ensures you can check if the server is busy processing any tasks before creating new ones.

### API Endpoints

#### 1. GET /status

Check current server status and running tasks.

**Parameters:**
- `password`: Password to access API (required)

**Response:**
```json
{
  "running_tasks": 1,
  "task_history": [
    {
      "task_id": "abc12345",
      "status": "started",
      "timestamp": "2024-01-15T10:30:00.123456"
    },
    {
      "task_id": "abc12345",
      "status": "completed",
      "timestamp": "2024-01-15T10:35:00.789012"
    }
  ],
  "is_busy": false
}
```

**Field meanings:**
- `running_tasks`: Number of running tasks
- `task_history`: History of 10 most recent tasks
- `is_busy`: `true` if tasks are running, `false` if server is idle

#### 2. POST /call (Updated)

Create new task with monitoring capability.

**New response:**
```json
{
  "message": "Success - new task created.",
  "task_id": "abc12345"
}
```

<a name="tm-usage"></a>

### Usage Examples

#### 1. Check server status
```bash
curl -s "http://localhost:9999/status?password=YOUR_PASSWORD" | jq .
```

#### 2. Wait until server is idle
```bash
# Use available script
./check-status.sh

# Or write your own loop
while true; do
    STATUS=$(curl -s "http://localhost:9999/status?password=YOUR_PASSWORD")
    IS_BUSY=$(echo "$STATUS" | jq -r '.is_busy')
    
    if [ "$IS_BUSY" = "false" ]; then
        echo "Server is free!"
        break
    fi
    
    echo "Server is busy, waiting..."
    sleep 5
done
```

#### 3. Create task and wait for completion
```bash
# Create task
RESPONSE=$(curl -s -X POST "http://localhost:9999/call" \
    -H "Content-Type: application/json" \
    -d '{
        "password": "YOUR_PASSWORD",
        "refresh_token": "YOUR_REFRESH_TOKEN",
        "client_id": "YOUR_CLIENT_ID",
        "client_secret": "YOUR_CLIENT_SECRET"
    }')

TASK_ID=$(echo "$RESPONSE" | jq -r '.task_id')
echo "Task created: $TASK_ID"

# Wait for task completion
while true; do
    STATUS=$(curl -s "http://localhost:9999/status?password=YOUR_PASSWORD")
    IS_BUSY=$(echo "$STATUS" | jq -r '.is_busy')
    
    if [ "$IS_BUSY" = "false" ]; then
        echo "Task completed!"
        break
    fi
    
    echo "Task still running..."
    sleep 5
done
```

<a name="tm-scripts"></a>

### Available Scripts

#### 1. api-calls.sh
Original script updated to include status checking:
```bash
./api-calls.sh
```

#### 2. check-status.sh
Dedicated script for checking and waiting tasks:
```bash
./check-status.sh
```

This script provides 3 options:
1. Only check current status
2. Create new task and wait for completion
3. Wait for current tasks to complete

<a name="github-secrets"></a>

## 🔐 GitHub Secrets Setup Guide

<a name="gs-config"></a>

### Security Configuration

For secure deployment with GitHub Actions, all sensitive information is stored in GitHub Secrets instead of committed files.

**Security Features:**
- ✅ Files `.env` and `profiles.json` are excluded via `.gitignore`
- ✅ Sensitive data only exists in GitHub Secrets
- ✅ Workflows automatically create config files from secrets
- ✅ No sensitive information in source code
- ✅ Safe for public repositories

<a name="gs-steps"></a>

### Step-by-step Setup

#### Step 1: Access GitHub Secrets

1. Go to your repository on GitHub
2. Click **Settings** (in the top menu)
3. Left sidebar → **Secrets and variables** → **Actions**

#### Step 2: Add Repository Secrets

Click **New repository secret** and add each secret below:

##### Secret 1: E5_CLIENT_ID
- **Name:** `E5_CLIENT_ID`
- **Secret:** Copy from current `.env` file (E5_CLIENT_ID line)

##### Secret 2: E5_CLIENT_SECRET
- **Name:** `E5_CLIENT_SECRET`  
- **Secret:** Copy from current `.env` file (E5_CLIENT_SECRET line)

##### Secret 3: E5_REFRESH_TOKEN
- **Name:** `E5_REFRESH_TOKEN`
- **Secret:** Copy from current `.env` file (E5_REFRESH_TOKEN line)

##### Secret 4: E5_WEB_APP_PASSWORD
- **Name:** `E5_WEB_APP_PASSWORD`
- **Secret:** Copy from current `.env` file (E5_WEB_APP_PASSWORD line)

##### Secret 5: PROFILES_JSON
- **Name:** `PROFILES_JSON`
- **Secret:** Copy entire content from current `profiles.json` file

**Note:** Paste the complete JSON content from your local `profiles.json` file into this secret (including curly braces and complete JSON formatting)

#### Step 3: Verification

After adding all 5 secrets, you should see:
- E5_CLIENT_ID
- E5_CLIENT_SECRET  
- E5_REFRESH_TOKEN
- E5_WEB_APP_PASSWORD
- PROFILES_JSON

#### Step 4: Test GitHub Actions

1. Go to **Actions** tab
2. Select workflow **Run E5 Auto Refresh** or **Run E5 Auto Refresh - Multi Profile**
3. Click **Run workflow** to test

### File Structure After Setup

```
cloudom/
├── .env.example          # Template file (safe to commit)
├── profiles.json.example # Template file (safe to commit)  
├── .env                  # Created by workflow (not in repo)
├── profiles.json         # Created by workflow (not in repo)
└── .gitignore           # Excludes sensitive files
```

<a name="deployment"></a>

## 🕹 Deployment

<a name="d-1"></a>

**1.Running locally:** *(Best for testing)*
  ```
  python main.py
  ```

<a name="d-2"></a>

**2.Using Docker:** *(Recommended)*
* Build own Docker image:
  ```
  docker build -t msft-e5-renewal .
  ```
* Run the Docker container:
  ```
  docker run -p 9999:9999 msft-e5-renewal
  ```

<a name="d-3"></a>

**3.GitHub Actions:** *(Automated & Secure)*

This project includes automated GitHub Actions workflows:

#### Multi-Profile Workflow
**File:** `.github/workflows/run-e5-multi-profile.yml`

**Features:**
- Automatically runs every 2 hours
- Supports manual trigger
- Checks profiles.json configuration
- Runs all profiles simultaneously
- Random delay to avoid rate limiting
- Displays result summary

**Usage:**
1. Configure GitHub Secrets with required environment variables
2. Configure GitHub Secret PROFILES_JSON with profile information
3. Push code to GitHub repository
4. Workflow will run automatically on schedule or manual trigger from Actions tab

**Security Notes:**
- Uses GitHub Secrets to protect sensitive information
- Sensitive files `.env` and `profiles.json` are created from secrets during workflow
- No sensitive data stored in source code
- Safe for public repositories

<a name="routes"></a>

## 🌐 Routes

* **/** - GET

  Retrieve server statistics in JSON format, including the server version, total received requests, total successful requests, and the total number of errors encountered thus far.

  * **Headers:**
    * None.
  * **Parameters:**
    * None.
  * **Example:**

    ```shell
    curl http://127.0.0.1:9999/
    ```

* **/call** - POST

  Command server to call Microsoft APIs on behalf of a user account.

  * **Headers:**

    ```json
    {"Content-Type":"application/json"}
    ```
  * **Parameters: (as JSON)**
    * `password` (*required*) - The web app password.
    * `client_id` (*optional*) - ID of your Azure Active Directory app. By default provided client ID in *config.py*.
    * `client_secret` (*optional*) - Secret of your Azure Active Directory app. By default provided client secret in *config.py*.
    * `refresh_token` (*optional*) - The refresh token of user account to act behalf of. By default provided refresh token in *config.py*.
  * **Example:**

    ```shell
    curl -X POST -H "Content-Type: application/json" -d '{"password":"RequiredPassword", "refresh_token": "OptionalRefreshToken"}' "http://127.0.0.1:9999/call"
    ```

* **/call-all-profiles** - POST

  Command server to call Microsoft APIs for all enabled profiles simultaneously.

  * **Headers:**

    ```json
    {"Content-Type":"application/json"}
    ```
  * **Parameters: (as JSON)**
    * `password` (*required*) - The web app password.
  * **Example:**

    ```shell
    curl -X POST -H "Content-Type: application/json" -d '{"password":"RequiredPassword"}' "http://127.0.0.1:9999/call-all-profiles"
    ```

* **/profiles** - GET

  View list of configured profiles with their status.

  * **Headers:**
    * None.
  * **Parameters: (in URL)**
    * `password` (*required*) - The web app password.
  * **Example:**

    ```shell
    curl "http://127.0.0.1:9999/profiles?password=RequiredPassword"
    ```

* **/status** - GET

  Check current server status and running tasks.

  * **Headers:**
    * None.
  * **Parameters: (in URL)**
    * `password` (*required*) - The web app password.
  * **Example:**

    ```shell
    curl "http://127.0.0.1:9999/status?password=RequiredPassword"
    ```

* **/logs** - GET

    Generate download request for current log file.

  * **Headers:**
    * None.
  * **Parameters: (in URL)**
    * `password` (*required*) - The web app password.
    * `as_file` (*optional*) - By default, this parameter is set to False, allowing you to choose whether to send logs as a file with options True or False.
  * **Example**

    ```shell
    curl -o "event-log.txt" "http://127.0.0.1:9999/logs?password=1234&as_file=True"
    ```

<a name="macos-guide"></a>

## 🍎 Running on macOS

**Simple guide to run Microsoft E5 Auto Renewal on macOS:**

### **Step 1: Install Homebrew (if not installed)**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### **Step 2: Install Python and Git**

```bash
brew install python@3.12 git
```

### **Step 3: Download the code**

```bash
git clone https://github.com/ledhcg/Microsoft-E5-Auto-Renewal.git
cd Microsoft-E5-Auto-Renewal
```

### **Step 4: Create virtual environment (recommended)**

```bash
python3 -m venv venv
source venv/bin/activate
```

### **Step 5: Install requirements**

```bash
pip install -r requirements.txt
```

### **Step 6: Setup configuration**

**Option 1: Use .env file**
```bash
touch .env
```

Edit the `.env` file with your information:
```bash
E5_CLIENT_ID=your_client_id_here
E5_CLIENT_SECRET=your_client_secret_here
E5_REFRESH_TOKEN=your_refresh_token_here
E5_WEB_APP_PASSWORD=your_strong_password_here
```

**Option 2: Edit config.py**
```bash
nano config.py  # or use any editor like vim, code
```

### **Step 7: Get Refresh Token**

```bash
python3 auth.py YOUR_CLIENT_ID YOUR_CLIENT_SECRET
```

Follow the instructions and copy the `refresh_token` value from the result.

### **Step 8: Run the application**

**Run in development mode:**
```bash
python3 main.py
```

**Run in background:**
```bash
nohup python3 main.py > app.log 2>&1 &
```

### **Step 9: Test if it works**

Open browser and go to:
```
http://localhost:9999
```

Or use curl:
```bash
curl http://localhost:9999
```

### **🔧 Common Issues on macOS**

**Python not found:**
```bash
# Add Python to PATH
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Permission denied:**
```bash
# Give execute permission
chmod +x main.py
```

**Port already in use:**
```bash
# Find and kill process using port 9999
lsof -ti:9999 | xargs kill -9
```

**Use different port:**
```bash
# Add to .env or config.py
PORT=9998
```

### **🚀 Auto-start with launchd**

Create plist file for auto-start:
```bash
mkdir -p ~/Library/LaunchAgents
```

Create file `~/Library/LaunchAgents/com.e5renewal.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.e5renewal</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/python3</string>
        <string>/path/to/your/Microsoft-E5-Auto-Renewal/main.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/path/to/your/Microsoft-E5-Auto-Renewal</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

Load and start service:
```bash
launchctl load ~/Library/LaunchAgents/com.e5renewal.plist
launchctl start com.e5renewal
```

<a name="credits"></a>

## ❤️ Credits & Thanks

[**Dinh Cuong (ledhcg)**](https://github.com/ledhcg): Owner & developer of Microsoft E5 Auto Renewal Tool.<br>