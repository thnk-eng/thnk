#!/bin/bash

# entrypoint.sh

# Exit immediately if a command exits with a non-zero status
set -e

# Wait for the database to be ready
echo "Waiting for the database to be ready..."
while ! nc -z "$SUPABSE_DATABASE_HOST" "$SUPABASE_DATABASE_PORT"; do
  sleep 1
done
echo "Database is ready."

# Collect static files
echo "Collecting static files..."
python manage.py collectstatic --noinput

# Apply database migrations
echo "Applying database migrations..."
python manage.py migrate --noinput

# Start Gunicorn server
echo "Starting Gunicorn server..."
exec gunicorn bubble_auth.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 3
