from uvicorn import run
from quart import Quart, request, Response as quartResponse, send_file
from httpx import AsyncClient as httpx_client
from asyncio import sleep as async_sleep, gather
from random import shuffle
from logging import getLogger
from config import *
import asyncio

class WebServer:
    instance = Quart(__name__)
    version = 2.1
    stats = {'version': version, 'totalRequests': 0, 'totalSuccess': 0, 'totalErrors': 0}

    def __init__(self):
        self.logger = getLogger('uvicorn')

        @self.instance.before_serving
        async def before_serve():
            host = f"127.0.0.1:{WEB_APP_PORT}" if WEB_APP_HOST == "0.0.0.0" else f"{WEB_APP_HOST}:{WEB_APP_PORT}"
            self.logger.info(f'Server running on {host}')

        @self.instance.after_serving
        async def after_serve():
            self.logger.info('Server is now stopped!')

        @self.instance.before_request
        async def before_request():
            self.stats['totalRequests'] += 1

        @self.instance.after_request
        async def after_request(response: quartResponse):
            if response.status_code == 201:
                self.stats['totalSuccess'] += 1
            elif response.status_code >= 401:
                self.stats['totalErrors'] += 1

            return response
        
        ErrorHandler(self.instance)
        RouteHandler(self.instance)

class HTTPError(Exception):
    status_code:int = None
    description:str = None
    def __init__(self, status_code, description):
        self.status_code = status_code
        self.description = description
        super().__init__(self.status_code, self.description)

class ErrorHandler:
    def __init__(self, instance: Quart):
        self.error_messages =  {
            400: 'Invalid request.',
            401: 'Password is required to use this route.',
            403: 'Access denied - invalid password.',
            404: 'Resource not found.',
            405: 'Invalid method',
            415: 'No json data passed.'
        }

        @instance.errorhandler(400)
        async def invalid_request(_):
            return 'Invalid request.', 400
        
        @instance.errorhandler(404)
        async def not_found(_):
            return 'Resource not found.', 404
        
        @instance.errorhandler(405)
        async def invalid_method(_):
            return 'Invalid request method.', 405
        
        @instance.errorhandler(HTTPError)
        async def http_error(error:HTTPError):
            error_message = self.error_messages[error.status_code]
            return error.description or error_message, error.status_code

    @classmethod
    def abort(cls, status_code:int = 500, description:str = None):
        raise HTTPError(status_code, description)

class RouteHandler:
    def __init__(self, instance: Quart):
    
        @instance.route('/')
        async def home():
            return WebServer.stats, 200

        @instance.route('/call', methods=['POST'])
        async def create_task():
            json_data = await request.json or ErrorHandler.abort(415)
            password = json_data.get('password') or ErrorHandler.abort(401)

            if password != WEB_APP_PASSWORD:
                ErrorHandler.abort(403)
            
            refresh_token = json_data.get('refresh_token')
            client_id = json_data.get('client_id')
            client_secret = json_data.get('client_secret')
            access_token = await HTTPClient.acquire_access_token(refresh_token, client_id, client_secret)

            import uuid
            task_id = str(uuid.uuid4())[:8]
            instance.add_background_task(HTTPClient.call_endpoints, access_token, task_id)

            return {'message': 'Success - new task created.', 'task_id': task_id}, 201
        
        @instance.route('/call-all-profiles', methods=['POST'])
        async def create_all_profiles_task():
            json_data = await request.json or ErrorHandler.abort(415)
            password = json_data.get('password') or ErrorHandler.abort(401)

            if password != WEB_APP_PASSWORD:
                ErrorHandler.abort(403)
            
            if not PROFILES:
                ErrorHandler.abort(400, 'No profiles configured. Please add profiles to profiles.json')
            
            import uuid
            batch_id = str(uuid.uuid4())[:8]
            task_ids = []
            
            for profile in PROFILES:
                task_id = f"{batch_id}-{profile['name']}"
                task_ids.append(task_id)
                instance.add_background_task(
                    HTTPClient.call_endpoints_for_profile, 
                    profile, 
                    task_id
                )
            
            return {
                'message': f'Success - {len(PROFILES)} profile tasks created.',
                'batch_id': batch_id,
                'task_ids': task_ids,
                'profiles_count': len(PROFILES)
            }, 201
        
        @instance.route('/profiles', methods=['GET'])
        async def get_profiles():
            password = request.args.get('password') or ErrorHandler.abort(401)
            
            if password != WEB_APP_PASSWORD:
                ErrorHandler.abort(403)
            
            profiles_info = []
            for profile in PROFILES:
                profiles_info.append({
                    'name': profile['name'],
                    'client_id': profile['client_id'][:8] + '...',  # Hide sensitive info
                    'enabled': profile.get('enabled', True)
                })
            
            return {
                'profiles': profiles_info,
                'total_count': len(PROFILES)
            }, 200
        
        @instance.route('/logs')
        async def send_logs():
            password = request.args.get('password') or ErrorHandler.abort(401)
            as_file = request.args.get('as_file', 'False') in {'TRUE', 'True', 'true'}

            if password != WEB_APP_PASSWORD:
                ErrorHandler.abort(403)

            return await send_file('event-log.txt', as_attachment=as_file)
        
        @instance.route('/status')
        async def get_task_status():
            password = request.args.get('password') or ErrorHandler.abort(401)
            
            if password != WEB_APP_PASSWORD:
                ErrorHandler.abort(403)
            
            return {
                'running_tasks': TaskManager.get_running_tasks_count(),
                'task_history': TaskManager.get_task_history(),
                'is_busy': TaskManager.is_busy()
            }, 200

class TaskManager:
    _running_tasks = 0
    _task_history = []
    _max_history = 10
    
    @classmethod
    def start_task(cls, task_id: str):
        cls._running_tasks += 1
        cls._add_to_history(task_id, 'started')
        
    @classmethod
    def finish_task(cls, task_id: str, success: bool = True):
        cls._running_tasks = max(0, cls._running_tasks - 1)
        status = 'completed' if success else 'failed'
        cls._add_to_history(task_id, status)
        
    @classmethod
    def get_running_tasks_count(cls):
        return cls._running_tasks
        
    @classmethod
    def is_busy(cls):
        return cls._running_tasks > 0
        
    @classmethod
    def get_task_history(cls):
        return cls._task_history.copy()
        
    @classmethod
    def _add_to_history(cls, task_id: str, status: str):
        from datetime import datetime
        entry = {
            'task_id': task_id,
            'status': status,
            'timestamp': datetime.now().isoformat()
        }
        cls._task_history.append(entry)
        if len(cls._task_history) > cls._max_history:
            cls._task_history.pop(0)

class HTTPClient:
    instance = httpx_client()
    token_endpoint = 'https://login.microsoftonline.com/common/oauth2/v2.0/token'
    graph_endpoints = [
            'https://graph.microsoft.com/v1.0/me/drive/root',
            'https://graph.microsoft.com/v1.0/me/drive',
            'https://graph.microsoft.com/v1.0/drive/root',
            'https://graph.microsoft.com/v1.0/users',
            'https://graph.microsoft.com/v1.0/me/messages',
            'https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messageRules',
            'https://graph.microsoft.com/v1.0/me/drive/root/children',
            'https://api.powerbi.com/v1.0/myorg/apps',
            'https://graph.microsoft.com/v1.0/me/mailFolders',
            'https://graph.microsoft.com/v1.0/me/outlook/masterCategories',
            'https://graph.microsoft.com/v1.0/applications?$count=true',
            'https://graph.microsoft.com/v1.0/me/?$select=displayName,skills',
            'https://graph.microsoft.com/v1.0/me/mailFolders/Inbox/messages/delta',
            'https://graph.microsoft.com/beta/me/outlook/masterCategories',
            'https://graph.microsoft.com/beta/me/messages?$select=internetMessageHeaders&$top=1',
            'https://graph.microsoft.com/v1.0/sites/root/lists',
            'https://graph.microsoft.com/v1.0/sites/root',
            'https://graph.microsoft.com/v1.0/sites/root/drives'
        ]

    @classmethod
    async def acquire_access_token(
        cls,
        refresh_token:str = None,
        client_id:str = None,
        client_secret:str = None
    ):
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        data = {
            'grant_type': 'refresh_token',
            'refresh_token': refresh_token or REFRESH_TOKEN,
            'client_id': client_id or CLIENT_ID,
            'client_secret': client_secret or CLIENT_SECRET,
            'redirect_uri': 'http://localhost:53682/'
        }

        response = await cls.instance.post(cls.token_endpoint, headers=headers, data=data)
        return response.json().get('access_token') or ErrorHandler.abort(
            401,
            'Failed to acquire the access token. Please verify your refresh token and try again.'
        )
    
    @classmethod
    async def call_endpoints(cls, access_token:str, task_id: str = None):
        import uuid
        if not task_id:
            task_id = str(uuid.uuid4())[:8]
            
        TaskManager.start_task(task_id)
        
        try:
            shuffle(cls.graph_endpoints)
            headers = {
                'Authorization': f'Bearer {access_token}',
                'Content-Type': 'application/json'
            }

            for endpoint in cls.graph_endpoints:
                await async_sleep(TIME_DELAY)
                try:
                    response = await cls.instance.get(endpoint, headers=headers)
                    # Log successful calls if needed
                except Exception as e:
                    # Log errors if needed
                    pass
            
            TaskManager.finish_task(task_id, True)
        except Exception as e:
            TaskManager.finish_task(task_id, False)
            raise
    
    @classmethod
    async def call_endpoints_for_profile(cls, profile: dict, task_id: str = None):
        """Call endpoints for a specific profile"""
        import uuid
        if not task_id:
            task_id = str(uuid.uuid4())[:8]
            
        TaskManager.start_task(task_id)
        
        try:
            # Get access token for this profile
            access_token = await cls.acquire_access_token(
                profile['refresh_token'],
                profile['client_id'],
                profile['client_secret']
            )
            
            shuffle(cls.graph_endpoints)
            headers = {
                'Authorization': f'Bearer {access_token}',
                'Content-Type': 'application/json'
            }

            for endpoint in cls.graph_endpoints:
                await async_sleep(TIME_DELAY)
                try:
                    response = await cls.instance.get(endpoint, headers=headers)
                    # Log successful calls if needed
                except Exception as e:
                    # Log errors if needed
                    pass
            
            TaskManager.finish_task(task_id, True)
        except Exception as e:
            TaskManager.finish_task(task_id, False)
            raise

web_server = WebServer().instance

if __name__ == '__main__':
    run(
        app="main:web_server",
        host=WEB_APP_HOST,
        port=WEB_APP_PORT,
        log_config=LOGGER_CONFIG_JSON,
        access_log=False
    )
