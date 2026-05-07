import json
import uuid
import functions_framework
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token
from google.cloud import storage
import config

_storage_client = None

def get_storage():
    global _storage_client
    if _storage_client is None:
        _storage_client = storage.Client()
    return _storage_client


def verify_google_token(token: str) -> str | None:
    try:
        info = id_token.verify_oauth2_token(
            token, google_requests.Request(), config.GOOGLE_CLIENT_ID
        )
        return info.get("email")
    except Exception:
        return None


def get_identity(request) -> tuple[str, str]:
    auth = request.headers.get("Authorization", "")
    if auth.startswith("Bearer "):
        email = verify_google_token(auth[7:])
        if email is None:
            raise ValueError("Invalid or expired Google token")
        if not config.ALLOW_ALL and email not in config.ALLOWED_USERS:
            raise ValueError("Account not authorized")
        return email, "google"

    device_id = request.headers.get("X-Device-ID", "").strip()
    if device_id:
        if not config.ALLOW_DEVICE_AUTH and not config.ALLOW_ALL:
            raise ValueError("Device auth is disabled. Sign in with Google.")
        return f"device_{device_id}", "device"

    raise ValueError("No authentication provided")


def load_todos(blob) -> list:
    if not blob.exists():
        return []
    return json.loads(blob.download_as_text()).get("todos", [])


def save_todos(blob, todos: list):
    blob.upload_from_string(json.dumps({"todos": todos}), content_type="application/json")


def data_blob(user_id: str):
    bucket = get_storage().bucket(config.BUCKET_NAME)
    return bucket.blob(f"{config.APP_NAME}/{user_id}/data.json")


def cors(request) -> dict:
    return {
        "Access-Control-Allow-Origin":  request.headers.get("Origin", "*"),
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, X-Device-ID, X-App-Name, Content-Type",
        "Access-Control-Max-Age":       "3600",
    }


def json_response(body, status=200, extra_headers=None):
    headers = {"Content-Type": "application/json"}
    if extra_headers:
        headers.update(extra_headers)
    return (json.dumps(body), status, headers)


@functions_framework.http
def handler(request):
    h = cors(request)

    if request.method == "OPTIONS":
        return ("", 204, h)

    try:
        user_id, _ = get_identity(request)
    except ValueError as e:
        return json_response({"error": str(e)}, 401, h)

    blob = data_blob(user_id)

    # GET /  — list all todos
    if request.method == "GET":
        return json_response({"todos": load_todos(blob), "user": user_id}, 200, h)

    # POST / body: {action: "add"|"toggle"|"delete", ...}
    if request.method == "POST":
        body = request.get_json(silent=True) or {}
        action = body.get("action")
        todos = load_todos(blob)

        if action == "add":
            text = (body.get("text") or "").strip()
            if not text:
                return json_response({"error": "text is required"}, 400, h)
            todos.append({"id": str(uuid.uuid4()), "text": text, "done": False})

        elif action == "toggle":
            tid = body.get("id")
            todos = [
                {**t, "done": not t["done"]} if t["id"] == tid else t
                for t in todos
            ]

        elif action == "delete":
            tid = body.get("id")
            todos = [t for t in todos if t["id"] != tid]

        else:
            return json_response({"error": "action must be add | toggle | delete"}, 400, h)

        save_todos(blob, todos)
        return json_response({"todos": todos}, 200, h)

    return json_response({"error": "Method not allowed"}, 405, h)
