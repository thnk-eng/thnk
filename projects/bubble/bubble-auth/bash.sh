#!/bin/bash

# ================================
# Script: deploy_django_gcloud.sh
# Description: Automates deployment of a Django 5.1 app with PostgreSQL to Google Cloud.
# ================================

set -e  # Exit immediately if a command exits with a non-zero status.

# -------------------------------
# Configuration Variables
# -------------------------------

# **Google Cloud Settings**
PROJECT_ID="your-project-id"                # Replace with your Google Cloud project ID
REGION="us-central1"                        # Replace with your preferred region
ZONE="us-central1-a"                        # Replace with your preferred zone

# **Cloud SQL Settings**
SQL_INSTANCE_NAME="your-sql-instance"       # Replace with your desired Cloud SQL instance name
SQL_DB_NAME="your-database-name"            # Replace with your PostgreSQL database name
SQL_DB_USER="postgres"                      # Default PostgreSQL user
SQL_DB_PASSWORD="your-db-password"          # Replace with a strong password

# **Django App Settings**
APP_NAME="your-django-app"                   # Replace with your Django app name
PYTHON_RUNTIME="python311"                  # Adjust if using a different Python version

# **Static Files Settings**
STATIC_BUCKET_NAME="your-static-bucket"      # Replace with your desired Cloud Storage bucket name

# **Other Settings**
ENABLE_CUSTOM_DOMAIN=false                   # Set to true if you want to configure a custom domain
CUSTOM_DOMAIN="yourdomain.com"              # Replace with your custom domain

# **Django Settings File Path**
SETTINGS_FILE="your_project/settings.py"     # Replace with the relative path to your settings.py

# -------------------------------
# Function Definitions
# -------------------------------

# Function to check if a gcloud component is installed
check_gcloud_component() {
    if ! gcloud components list --format="value(id)" | grep -q "^$1$"; then
        echo "Installing gcloud component: $1"
        gcloud components install "$1" --quiet
    else
        echo "gcloud component '$1' is already installed."
    fi
}

# Function to initialize gcloud and set the project
initialize_gcloud() {
    echo "Initializing gcloud..."
    gcloud auth login
    gcloud config set project "$PROJECT_ID"
    gcloud config set compute/region "$REGION"
    gcloud config set compute/zone "$ZONE"
}

# Function to enable required Google Cloud APIs
enable_apis() {
    echo "Enabling required Google Cloud APIs..."
    gcloud services enable appengine.googleapis.com \
        cloudsql.googleapis.com \
        compute.googleapis.com \
        storage.googleapis.com \
        secretmanager.googleapis.com
}

# Function to create a new Google Cloud project (optional)
create_project() {
    echo "Creating Google Cloud project: $PROJECT_ID"
    gcloud projects create "$PROJECT_ID" --set-as-default
}

# Function to create App Engine application
create_app_engine() {
    echo "Creating App Engine application..."
    gcloud app create --project="$PROJECT_ID" --region="$REGION"
}

# Function to create a Cloud SQL instance
create_cloud_sql_instance() {
    echo "Creating Cloud SQL instance: $SQL_INSTANCE_NAME"
    gcloud sql instances create "$SQL_INSTANCE_NAME" \
        --database-version=POSTGRES_14 \
        --tier=db-f1-micro \
        --region="$REGION"

    echo "Setting Cloud SQL root password..."
    echo "$SQL_DB_PASSWORD" | gcloud sql users set-password "$SQL_DB_USER" \
        --host="%" \
        --instance="$SQL_INSTANCE_NAME" \
        --password="$SQL_DB_PASSWORD"

    echo "Creating PostgreSQL database: $SQL_DB_NAME"
    gcloud sql databases create "$SQL_DB_NAME" --instance="$SQL_INSTANCE_NAME"
}

# Function to configure Django settings.py
configure_django_settings() {
    echo "Configuring Django settings.py for Google Cloud deployment..."

    # Backup the original settings.py
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"

    # Update ALLOWED_HOSTS
    sed -i "s/^ALLOWED_HOSTS = .*/ALLOWED_HOSTS = ['*']/" "$SETTINGS_FILE"

    # Configure Database settings
    cat <<EOL >> "$SETTINGS_FILE"

import os

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': os.environ.get('DB_HOST', '/cloudsql/$PROJECT_ID:$REGION:$SQL_INSTANCE_NAME'),
        'NAME': os.environ.get('DB_NAME'),
        'USER': os.environ.get('DB_USER'),
        'PASSWORD': os.environ.get('DB_PASSWORD'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'static')

# Whitenoise middleware for serving static files
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    # ... existing middleware ...
]
EOL

    echo "Django settings.py configured."
}

# Function to install Python dependencies
install_dependencies() {
    echo "Installing Python dependencies..."
    pip install --upgrade pip
    pip install gunicorn psycopg2-binary whitenoise
    pip freeze > requirements.txt
}

# Function to create app.yaml for App Engine
create_app_yaml() {
    echo "Creating app.yaml for App Engine deployment..."

    cat <<EOL > app.yaml
runtime: $PYTHON_RUNTIME
env: standard

entrypoint: /bin/bash -c "python manage.py migrate && gunicorn your_project.wsgi:application --bind :\$PORT"

handlers:
  - url: /static
    static_dir: static/

  - url: /.*
    script: auto

env_variables:
  DB_HOST: /cloudsql/$PROJECT_ID:$REGION:$SQL_INSTANCE_NAME
  DB_NAME: $SQL_DB_NAME
  DB_USER: $SQL_DB_USER
  DB_PASSWORD: $SQL_DB_PASSWORD
  DB_PORT: 5432
EOL

    echo "app.yaml created with migration step."
}

# Function to create a Cloud Storage bucket for static files
create_storage_bucket() {
    echo "Creating Cloud Storage bucket for static files: $STATIC_BUCKET_NAME"
    gsutil mb -l "$REGION" gs://"$STATIC_BUCKET_NAME"/
    gsutil iam ch allUsers:objectViewer gs://"$STATIC_BUCKET_NAME"
}

# Function to collect static files and upload to Cloud Storage
collect_and_upload_static() {
    echo "Collecting static files..."
    python manage.py collectstatic --noinput

    echo "Uploading static files to Cloud Storage bucket..."
    gsutil -m cp -r static/* gs://"$STATIC_BUCKET_NAME"/static/
}

# Function to deploy the Django app to App Engine
deploy_app_engine() {
    echo "Deploying the Django app to App Engine..."
    gcloud app deploy app.yaml --quiet
}

# Function to set up Secret Manager for sensitive data
setup_secret_manager() {
    echo "Setting up Secret Manager for sensitive environment variables..."

    # Create a secret for DB_PASSWORD
    echo -n "$SQL_DB_PASSWORD" | gcloud secrets create db-password --data-file=-

    # Update app.yaml to use Secret Manager
    sed -i "/DB_PASSWORD:/c\  DB_PASSWORD: \$(SECRET_MANAGER:db-password)" app.yaml

    echo "Secret Manager setup completed."
}

# Function to configure a custom domain (optional)
configure_custom_domain() {
    if [ "$ENABLE_CUSTOM_DOMAIN" = true ]; then
        echo "Configuring custom domain: $CUSTOM_DOMAIN"
        gcloud app domain-mappings create "$CUSTOM_DOMAIN"
        echo "Custom domain configured. SSL certificates are managed automatically."
    else
        echo "Custom domain configuration skipped."
    fi
}

# Function to display completion message
completion_message() {
    echo "======================================="
    echo "Django app deployed successfully to Google Cloud!"
    echo "Access your app at: https://$PROJECT_ID.appspot.com"
    if [ "$ENABLE_CUSTOM_DOMAIN" = true ]; then
        echo "Or at your custom domain: https://$CUSTOM_DOMAIN"
    fi
    echo "======================================="
}

# -------------------------------
# Main Script Execution
# -------------------------------

# Check for required gcloud components
check_gcloud_component "app-engine-python"

# Initialize gcloud and set project
initialize_gcloud

# Enable necessary APIs
enable_apis

# Optionally, create a new project (uncomment if needed)
# create_project

# Create App Engine application
create_app_engine

# Create Cloud SQL instance
create_cloud_sql_instance

# Install Python dependencies
install_dependencies

# Configure Django settings.py
configure_django_settings

# Create app.yaml with migration step
create_app_yaml

# Create Cloud Storage bucket for static files
create_storage_bucket

# Collect and upload static files
collect_and_upload_static

# Deploy the app to App Engine
deploy_app_engine

# Optionally, set up Secret Manager (uncomment if needed)
setup_secret_manager

# Optionally, configure a custom domain
configure_custom_domain

# Display completion message
completion_message
