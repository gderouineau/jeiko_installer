#!/bin/bash

echo "🧩 [finalize.sh] Finalisation de l'installation..."

PROJECT_DIR="$BASE_DIR/$SITE_NAME"
VENV_DIR="$PROJECT_DIR/venv"
MANAGE="$PROJECT_DIR/manage.py"
SERVICE_NAME="gunicorn-$SITE_NAME"

# Activer venv
source "$VENV_DIR/bin/activate"

# 1. Migrations
echo "🔄 Application des migrations..."
python "$MANAGE" migrate --noinput

# 2. Collectstatic
echo "📦 Collecte des fichiers statiques..."
python "$MANAGE" collectstatic --noinput

# 3. Création superuser
echo "👤 Création du superutilisateur Django..."
python "$MANAGE" shell <<EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username="$DJANGO_SUPERUSER").exists():
    User.objects.create_superuser(
        username="$DJANGO_SUPERUSER",
        email="$DJANGO_SUPEREMAIL",
        password="$DJANGO_SUPERPASS"
    )
    print("✅ Superuser créé.")
else:
    print("ℹ️ Superuser déjà existant.")
EOF

# 4. Redémarrage des services
echo "🔁 Redémarrage des services Gunicorn et Nginx..."
systemctl restart "$SERVICE_NAME"
systemctl reload nginx

# 5. Message de fin
echo ""
echo "🎉 Installation terminée pour $SITE_NAME !"
echo "🌍 Accès : https://$DOMAIN_NAME"
echo "🔐 Admin : https://$DOMAIN_NAME/admin/"
