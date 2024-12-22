# README


## **Project Structure**

Here's an overview of the project structure:

```
bubble_auth/
├── Dockerfile
├── entrypoint.sh
├── manage.py
├── pyproject.toml
├── poetry.lock
├── bubble_auth/
│   ├── __init__.py
│   ├── asgi.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── auth_app/
│   ├── __init__.py
│   ├── admin.py
│   ├── apps.py
│   ├── authentication.py
│   ├── forms.py
│   ├── models.py
│   ├── templates/
│   │   └── auth_app/
│   │       ├── dashboard.html
│   │       ├── login.html
│   │       └── register.html
│   ├── tests.py
│   ├── urls.py
│   └── views.py
├── static/
│   └── ... (your static files)
├── templates/
│   └── auth_app/
│       └── ... (if using project-level templates)
└── k8s/
    ├── configmap.yaml
    ├── secret.yaml
    ├── deployment.yaml
    ├── service.yaml
    └── ingress.yaml (optional)
```

---

## **1. `settings.py`**

Update your `settings.py` to use Supabase as the database backend.

```python
# bubble_auth/settings.py

import os
from pathlib import Path
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

# Secret key
SECRET_KEY = os.getenv('SECRET_KEY', 'your-default-secret-key')

# Debug mode
DEBUG = os.getenv('DEBUG', 'False') == 'True'

# Allowed hosts
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', '').split(',')

# Application definition
INSTALLED_APPS = [
    # Default Django apps
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Third-party apps
    'corsheaders',
    'rest_framework',
    'rest_framework.authtoken',
    'storages',
    # Your apps
    'auth_app',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  # If using CORS
    'django.middleware.security.SecurityMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
]

ROOT_URLCONF = 'bubble_auth.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],  # Project-level templates directory
        'APP_DIRS': True,  # Enable app-level templates
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',  # Required for admin
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'bubble_auth.wsgi.application'

# Database configuration (Supabase)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DATABASE_NAME', 'postgres'),
        'USER': os.getenv('DATABASE_USER', 'postgres'),
        'PASSWORD': os.getenv('DATABASE_PASSWORD', ''),
        'HOST': os.getenv('DATABASE_HOST', ''),
        'PORT': os.getenv('DATABASE_PORT', '6543'),  # Supabase default port
        'OPTIONS': {
            'sslmode': 'require',
        },
    }
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    # Add other validators as needed
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Media files
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'mediafiles'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Authentication backends
AUTHENTICATION_BACKENDS = [
    'auth_app.authentication.EmailBackend',
    'django.contrib.auth.backends.ModelBackend',
]

# REST framework settings
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
}

# Simple JWT settings
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=1),
    'SIGNING_KEY': os.getenv('JWT_SECRET_KEY', SECRET_KEY),
    'AUTH_HEADER_TYPES': ('Bearer',),
}

# Security settings
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_SECURE = not DEBUG
SECURE_HSTS_SECONDS = 31536000  # 1 year
SECURE_HSTS_PRELOAD = True
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_CONTENT_TYPE_NOSNIFF = True

# CORS settings (if needed)
CORS_ALLOWED_ORIGINS = os.getenv('CORS_ALLOWED_ORIGINS', '').split(',')

# Google Cloud Storage settings
if os.getenv('USE_CLOUD_STORAGE', 'False') == 'True':
    GS_BUCKET_NAME = os.getenv('GS_BUCKET_NAME')
    DEFAULT_FILE_STORAGE = 'storages.backends.gcloud.GoogleCloudStorage'
    STATICFILES_STORAGE = 'storages.backends.gcloud.GoogleCloudStorage'
    GS_DEFAULT_ACL = 'publicRead'
    STATIC_URL = f'https://storage.googleapis.com/{GS_BUCKET_NAME}/static/'
    MEDIA_URL = f'https://storage.googleapis.com/{GS_BUCKET_NAME}/media/'

# Logging configuration (optional, but recommended)
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '[{levelname}] {asctime} {module}: {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
}
```

**Note:** Ensure that you have the correct Supabase database credentials set in your environment variables or Kubernetes Secrets.

---

## **2. `entrypoint.sh`**

Adjust `entrypoint.sh` to ensure it works with Supabase. You might need to remove or adjust the database readiness check.

```bash
#!/bin/bash

# entrypoint.sh

# Exit immediately if a command exits with a non-zero status
set -e

# Wait for the database to be ready (optional)
echo "Waiting for the database to be ready..."
while ! nc -z $DATABASE_HOST $DATABASE_PORT; do
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
```

**Note:** Ensure that `nc` (netcat) is installed in your Docker image if you're using the database readiness check. Alternatively, you can remove the readiness check if Supabase is always available.

---

## **3. `Dockerfile`**

Adjust the `Dockerfile` as necessary.

```dockerfile
# Dockerfile

# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && \
    apt-get install -y netcat gcc && \
    rm -rf /var/lib/apt/lists/*

# Install Poetry
RUN pip install --upgrade pip
RUN pip install poetry

# Copy only the necessary files for dependencies first
COPY pyproject.toml poetry.lock /app/

# Install dependencies
RUN poetry config virtualenvs.create false
RUN poetry install --no-dev --no-interaction --no-ansi

# Copy the application code
COPY . /app/

# Make entrypoint.sh executable
RUN chmod +x /app/entrypoint.sh

# Expose port 8000
EXPOSE 8000

# Start the application
ENTRYPOINT ["/app/entrypoint.sh"]
```

---

## **4. Kubernetes Manifests**

Update your Kubernetes manifests to remove the Cloud SQL Proxy and adjust environment variables for Supabase.

### **a. `configmap.yaml`**

```yaml
# k8s/configmap.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: bubble-auth-config
data:
  DJANGO_SETTINGS_MODULE: bubble_auth.settings
  DEBUG: "False"
  USE_CLOUD_STORAGE: "True"
```

### **b. `secret.yaml`**

```yaml
# k8s/secret.yaml

apiVersion: v1
kind: Secret
metadata:
  name: bubble-auth-secret
type: Opaque
stringData:
  SECRET_KEY: "<your-secret-key>"
  JWT_SECRET_KEY: "<your-jwt-secret-key>"
  DATABASE_NAME: "<your-supabase-database-name>"
  DATABASE_USER: "<your-supabase-database-user>"
  DATABASE_PASSWORD: "<your-supabase-database-password>"
  DATABASE_HOST: "<your-supabase-database-host>"
  DATABASE_PORT: "6543"  # Supabase default port
  ALLOWED_HOSTS: "your-domain.com"
  GS_BUCKET_NAME: "<your-gcs-bucket-name>"
  GOOGLE_APPLICATION_CREDENTIALS_JSON: |
    {
      "type": "service_account",
      "project_id": "<your-gcp-project-id>",
      "private_key_id": "<your-private-key-id>",
      "private_key": "<your-private-key>",
      "client_email": "<your-service-account-email>",
      "client_id": "<your-client-id>",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url": "<your-cert-url>"
    }
```

**Important:** Replace placeholders with your actual Supabase and GCP credentials.

### **c. `deployment.yaml`**

```yaml
# k8s/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: bubble-auth-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: bubble-auth
  template:
    metadata:
      labels:
        app: bubble-auth
    spec:
      containers:
      - name: bubble-auth
        image: gcr.io/<your-gcp-project-id>/bubble-auth:latest
        ports:
        - containerPort: 8000
        envFrom:
        - configMapRef:
            name: bubble-auth-config
        - secretRef:
            name: bubble-auth-secret
        env:
        - name: GOOGLE_APPLICATION_CREDENTIALS
          value: /var/secrets/google/credentials.json
        volumeMounts:
        - name: google-credentials
          mountPath: /var/secrets/google
        readinessProbe:
          httpGet:
            path: /
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 8000
          initialDelaySeconds: 15
          periodSeconds: 20
      volumes:
      - name: google-credentials
        secret:
          secretName: bubble-auth-secret
          items:
            - key: GOOGLE_APPLICATION_CREDENTIALS_JSON
              path: credentials.json
```

**Note:** We have removed the `cloud-sql-proxy` container and related configurations since we're using Supabase.

### **d. `service.yaml`**

```yaml
# k8s/service.yaml

apiVersion: v1
kind: Service
metadata:
  name: bubble-auth-service
spec:
  selector:
    app: bubble-auth
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
  type: LoadBalancer
```

### **e. `ingress.yaml`** (Optional)

```yaml
# k8s/ingress.yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bubble-auth-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "bubble-auth-ip"
    kubernetes.io/ingress.class: "gce"
spec:
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: bubble-auth-service
            port:
              number: 80
```

---

## **5. Additional Files**

### **a. `pyproject.toml`**

Ensure you have the necessary dependencies:

```toml
[tool.poetry]
name = "bubble-auth"
version = "0.1.0"
description = "Bubble Auth Django Application"
authors = ["Your Name <you@example.com>"]
readme = "README.md"

[tool.poetry.dependencies]
python = "^3.12"
Django = "^5.1"
psycopg2-binary = "^2.9"
gunicorn = "^21.2"
django-cors-headers = "^4.0"
djangorestframework = "^3.14"
djangorestframework-simplejwt = "^5.2"
django-storages = "^1.13.2"
google-cloud-storage = "^2.10.0"
poetry = "^1.7"

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"
```

### **b. `.dockerignore`**

Create a `.dockerignore` file to exclude unnecessary files from the Docker build context:

```
.git
.gitignore
__pycache__/
*.pyc
.env
.env.*
.idea
.vscode
Dockerfile
entrypoint.sh
k8s/
```

---

## **6. Deployment Steps**

### **a. Build and Push Docker Image**

Authenticate Docker with GCP Container Registry:

```bash
gcloud auth configure-docker
```

Build and push the Docker image:

```bash
docker build -t gcr.io/<your-gcp-project-id>/bubble-auth:latest .
docker push gcr.io/<your-gcp-project-id>/bubble-auth:latest
```

### **b. Deploy to GKE**

Apply the Kubernetes manifests:

```bash
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

If using Ingress:

```bash
kubectl apply -f k8s/ingress.yaml
```

---

## **7. Security Considerations**

- **Secrets Management:** Use Kubernetes Secrets to store sensitive data. Ensure that secrets are not exposed in logs or error messages.
- **SSL/TLS:** Configure SSL/TLS for your application. Use a managed certificate with your Ingress or set up HTTPS with your domain.
- **Access Control:** Limit permissions for service accounts to the minimum required.
- **Supabase Security:** Ensure your Supabase credentials are kept secure. Supabase provides secure access methods; follow their guidelines for securing your database.
- **Regular Updates:** Keep your dependencies and base images up to date to patch vulnerabilities.

---

## **8. Handling Static and Media Files with Google Cloud Storage**

### **a. Create a GCS Bucket**

- Create a bucket named `<your-gcs-bucket-name>`.

### **b. Grant Permissions**

- Grant the service account access to the bucket.

### **c. Ensure Credentials are Available**

- The `GOOGLE_APPLICATION_CREDENTIALS_JSON` in `bubble-auth-secret` provides access.

---

## **9. Testing and Verification**

- **Check Pods and Services**

  ```bash
  kubectl get pods
  kubectl get services
  kubectl get ingress
  ```

- **View Logs**

  ```bash
  kubectl logs deployment/bubble-auth-deployment
  ```

- **Monitor Application**

  Use GCP's monitoring tools to keep track of application health.

---

## **10. Additional Considerations**

### **a. CORS Settings (If Applicable)**

If your authentication service will be accessed by other domains:

```python
# settings.py

CORS_ALLOWED_ORIGINS = os.getenv('CORS_ALLOWED_ORIGINS', '').split(',')
```

Set the `CORS_ALLOWED_ORIGINS` environment variable in your ConfigMap or Secret.

### **b. Allowed Hosts**

Ensure `ALLOWED_HOSTS` includes all domains that will access your application.

---

## supabase

- install docker && supabase

```bash
brew install supabase;
brew install docker
```

- go to `supabase` directory

```bash
supabase login;
supabase start;
supabase link <project_name> 
```

```bash
supabase status;
supabase link <project_name> 
```

```bash
receipt hash .env
I, [2024-10-01T10:09:25.614386 #35492]  INFO -- : Hashing file: .env
File hash: 5c99f708924a0ae17704bdca182d18c3408b9085fc47de804871c7e288ec1515
```

```bash
~/bubble-auth git:[main]
receipt encrypt .env
I, [2024-10-01T10:10:13.876555 #35833]  INFO -- : Encrypting file: .env
I, [2024-10-01T10:10:13.877481 #35833]  INFO -- : File encrypted to .env.enc
```