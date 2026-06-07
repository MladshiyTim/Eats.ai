"""
Firebase Cloud Messaging (HTTP v1) push sender.

Credentials are loaded from one of:
  - FIREBASE_CREDENTIALS_JSON  : the full service-account JSON as a string
  - GOOGLE_APPLICATION_CREDENTIALS : path to the service-account JSON file

If neither is set, sending is a no-op (returns gracefully) so the rest of the
app keeps working without Firebase configured.
"""

import os
import json
import threading

import requests

_FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'

# Cache the google credentials object across calls (it refreshes its own token).
_lock = threading.Lock()
_credentials = None
_project_id = None


def _load_credentials():
    """Return (credentials, project_id) or (None, None) if not configured."""
    global _credentials, _project_id
    with _lock:
        if _credentials is not None:
            return _credentials, _project_id

        try:
            from google.oauth2 import service_account  # lazy import
        except ImportError:
            return None, None

        info = None
        raw = os.environ.get('FIREBASE_CREDENTIALS_JSON', '').strip()
        if raw:
            try:
                info = json.loads(raw)
            except json.JSONDecodeError:
                return None, None
        else:
            path = os.environ.get('GOOGLE_APPLICATION_CREDENTIALS', '').strip()
            if path and os.path.exists(path):
                with open(path, 'r', encoding='utf-8') as fh:
                    info = json.load(fh)

        if not info:
            return None, None

        creds = service_account.Credentials.from_service_account_info(
            info, scopes=[_FCM_SCOPE]
        )
        _credentials = creds
        _project_id = os.environ.get('FIREBASE_PROJECT_ID') or info.get('project_id')
        return _credentials, _project_id


def is_configured() -> bool:
    creds, project_id = _load_credentials()
    return bool(creds and project_id)


def _access_token(creds) -> str:
    from google.auth.transport.requests import Request as GoogleRequest
    if not creds.valid:
        creds.refresh(GoogleRequest())
    return creds.token


def send_to_token(token: str, title: str, body: str, data: dict | None = None) -> bool:
    """Send a single notification. Returns True on success.

    Raises requests.HTTPError only for unexpected errors; an invalid/expired
    token returns False so the caller can deactivate it.
    """
    creds, project_id = _load_credentials()
    if not creds or not project_id:
        return False

    access_token = _access_token(creds)
    url = f'https://fcm.googleapis.com/v1/projects/{project_id}/messages:send'
    message = {
        'message': {
            'token': token,
            'notification': {'title': title, 'body': body},
            'android': {
                'priority': 'high',
                'notification': {'channel_id': 'eats_ai_reminders'},
            },
            'data': {str(k): str(v) for k, v in (data or {}).items()},
        }
    }

    resp = requests.post(
        url,
        headers={
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json',
        },
        json=message,
        timeout=(10, 30),
    )

    if resp.status_code == 200:
        return True

    # 404 UNREGISTERED / 400 INVALID_ARGUMENT → token is dead, tell caller.
    if resp.status_code in (400, 403, 404):
        return False

    resp.raise_for_status()
    return False


def send_to_user(user, title: str, body: str, data: dict | None = None) -> int:
    """Send to all of a user's active devices. Deactivates dead tokens.

    Returns the number of devices the message was accepted for.
    """
    from .models import DeviceToken  # avoid circular import

    if not is_configured():
        return 0

    delivered = 0
    for device in DeviceToken.objects.filter(user=user, is_active=True):
        try:
            ok = send_to_token(device.token, title, body, data)
        except requests.RequestException:
            # Network/server hiccup — keep token, try again next cycle.
            continue
        if ok:
            delivered += 1
        else:
            device.is_active = False
            device.save(update_fields=['is_active'])
    return delivered
