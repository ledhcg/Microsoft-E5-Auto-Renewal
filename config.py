from os import environ as env
from dotenv import load_dotenv
import json
from pathlib import Path

# Load .env file
load_dotenv()

"""
The program will load values from .env file first, then fall back to environment variables.
For multi-profile support, profiles are loaded from profiles.json file.
"""

# Legacy single profile support (backward compatibility)
REFRESH_TOKEN = env.get("E5_REFRESH_TOKEN")
CLIENT_ID = env.get("E5_CLIENT_ID")
CLIENT_SECRET = env.get("E5_CLIENT_SECRET")

# Multi-profile support
def load_profiles():
    """Load profiles from profiles.json file"""
    profiles_file = Path(__file__).parent / "profiles.json"
    if profiles_file.exists():
        try:
            with open(profiles_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return [profile for profile in data.get('profiles', []) if profile.get('enabled', True)]
        except (json.JSONDecodeError, FileNotFoundError, KeyError) as e:
            print(f"Error loading profiles: {e}")
            return []
    return []

# Load all enabled profiles
PROFILES = load_profiles()

# If no profiles found, create default profile from env vars
if not PROFILES and (CLIENT_ID and CLIENT_SECRET and REFRESH_TOKEN):
    PROFILES = [{
        'name': 'default',
        'client_id': CLIENT_ID,
        'client_secret': CLIENT_SECRET,
        'refresh_token': REFRESH_TOKEN,
        'enabled': True
    }]
WEB_APP_PASSWORD = env.get("E5_WEB_APP_PASSWORD")
WEB_APP_HOST = env.get("E5_WEB_APP_HOST", "0.0.0.0")
WEB_APP_PORT = int(env.get("E5_WEB_APP_PORT", 9999))
TIME_DELAY = int(env.get("E5_TIME_DELAY", 3))

# WEB SERVER LOGGING CONFIGURATION
LOGGER_CONFIG_JSON = {
    'version': 1,
    'formatters': {
        'default': {
            'format': '[%(asctime)s][%(name)s][%(levelname)s] -> %(message)s',
            'datefmt': '%d/%m/%Y %H:%M:%S'
        },
    },
    'handlers': {
        'file_handler': {
            'class': 'logging.FileHandler',
            'filename': 'event-log.txt',
            'formatter': 'default'
        },
        'stream_handler': {
            'class': 'logging.StreamHandler',
            'formatter': 'default'
        }
    },
    'loggers': {
        'uvicorn': {
            'level': 'INFO',
            'handlers': ['file_handler', 'stream_handler']
        },
        'uvicorn.error': {
            'level': 'WARNING',
            'handlers': ['file_handler', 'stream_handler']
        },
        'httpx': {
            'level': 'INFO',
            'handlers': ['file_handler', 'stream_handler']
        }
    }
}
