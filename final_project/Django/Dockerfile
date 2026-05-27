FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq5 \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY app/ .

RUN python manage.py collectstatic --noinput || true

EXPOSE 8000

CMD ["gunicorn", "django_app.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
