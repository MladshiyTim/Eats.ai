FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt /app/requirements.txt

RUN pip install --upgrade pip \
    && pip install -r /app/requirements.txt

COPY . /app

RUN python manage.py collectstatic --noinput

CMD python manage.py migrate && gunicorn healthai.wsgi:application --bind 0.0.0.0:${PORT:-8000}
