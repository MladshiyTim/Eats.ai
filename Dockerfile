FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY backend/requirements.txt /app/backend/requirements.txt

RUN pip install --upgrade pip \
    && pip install -r /app/backend/requirements.txt

COPY backend /app/backend

WORKDIR /app/backend

RUN python manage.py collectstatic --noinput

CMD ["sh", "-c", "python manage.py migrate && if [ -n \"$DJANGO_SUPERUSER_USERNAME\" ] && [ -n \"$DJANGO_SUPERUSER_PASSWORD\" ]; then python manage.py createsuperuser --noinput --username \"$DJANGO_SUPERUSER_USERNAME\" --email \"${DJANGO_SUPERUSER_EMAIL:-admin@example.com}\" || true; fi && gunicorn healthai.wsgi:application --bind 0.0.0.0:${PORT:-8000}"]
