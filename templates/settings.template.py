import os
from pathlib import Path
from dotenv import load_dotenv

# ───────────────────────────────────────────────
# Chargement de l'environnement .env
# ───────────────────────────────────────────────
BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(os.path.join(BASE_DIR, os.path.basename(__file__), '..', '.env'))

# ───────────────────────────────────────────────
# Paramètres principaux
# ───────────────────────────────────────────────
SECRET_KEY = os.getenv("SECRET_KEY", "insecure-default")
DEBUG = os.getenv("DEBUG", "False") == "True"

ALLOWED_HOSTS = [os.getenv("DOMAIN_NAME", "127.0.0.1")]

# ───────────────────────────────────────────────
# Applications installées
# ───────────────────────────────────────────────
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.sites',
    'django.contrib.staticfiles',

    # JEIKO
    'jeiko',
    'jeiko.administration',
    'jeiko.administration_menu',
    'jeiko.administration_pages',
    'jeiko.calendars',
    'jeiko.questionnaires_expert',
    'jeiko.users',

    # AUTHENTIFICATION
    'allauth',
    'allauth.account',
    'allauth.socialaccount',
    'allauth.socialaccount.providers.google',
    'allauth.socialaccount.providers.apple',
    'allauth.socialaccount.providers.facebook',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'allauth.account.middleware.AccountMiddleware',
    "django.middleware.cache.UpdateCacheMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.cache.FetchFromCacheMiddleware",
]

ROOT_URLCONF = '${SITE_NAME}.urls'
WSGI_APPLICATION = '${SITE_NAME}.wsgi.application'

SITE_ID = 1
X_FRAME_OPTIONS = "SAMEORIGIN"

CACHE_MIDDLEWARE_KEY_PREFIX = "cache_"
CACHE_MIDDLEWARE_SECONDS = 20000000

# ───────────────────────────────────────────────
# Templates
# ───────────────────────────────────────────────
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [
            os.path.join(BASE_DIR, 'templates/'),
        ],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.template.context_processors.i18n',
                'django.template.context_processors.media',
                'django.template.context_processors.static',
                'django.template.context_processors.tz',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# ───────────────────────────────────────────────
# Base de données PostgreSQL (via .env)
# ───────────────────────────────────────────────
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': os.getenv("DB_NAME"),
        'USER': os.getenv("DB_USER"),
        'PASSWORD': os.getenv("DB_PASS"),
        'HOST': 'localhost',
        'PORT': '',
    }
}

# ───────────────────────────────────────────────
# Authentification
# ───────────────────────────────────────────────
AUTHENTICATION_BACKENDS = [
    'django.contrib.auth.backends.ModelBackend',
    'allauth.account.auth_backends.AuthenticationBackend',
]

LOGIN_REDIRECT_URL = '/'
LOGOUT_REDIRECT_URL = '/'

ACCOUNT_EMAIL_REQUIRED = True
ACCOUNT_EMAIL_VERIFICATION = 'none'
ACCOUNT_AUTHENTICATION_METHOD = 'username_email'
ACCOUNT_USERNAME_REQUIRED = True
ACCOUNT_UNIQUE_EMAIL = True

ACCOUNT_FORMS = {
    'signup': 'jeiko.users.forms.CustomSignupForm',
    'login': 'jeiko.users.forms.CustomLoginForm',
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# ───────────────────────────────────────────────
# Statique & Media
# ───────────────────────────────────────────────
STATIC_URL = 'static/'
MEDIA_URL = 'media/'
STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static')]
STATIC_ROOT = os.path.join(BASE_DIR, 'staticdir')
MEDIA_ROOT = os.path.join(BASE_DIR, 'mediadir')

# ───────────────────────────────────────────────
# Sécurité HTTPS
# ───────────────────────────────────────────────
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
CSRF_TRUSTED_ORIGINS = [f"https://{os.getenv('DOMAIN_NAME')}"]

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'

GUNICORN_SOCKET = os.getenv("GUNICORN_SOCKET")