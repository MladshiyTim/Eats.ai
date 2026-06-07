"""
WSGI config for healthai project.
"""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'healthai.settings')

application = get_wsgi_application()
