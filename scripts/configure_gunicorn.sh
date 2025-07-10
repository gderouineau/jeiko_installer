#!/bin/bash

echo "🔥 [configure_gunicorn.sh] Configuration du service Gunicorn..."

SERVICE_NAME="gunicorn-$SITE_NAME"
PROJECT_DIR="$BASE_DIR/$SITE_NAME"
VENV_DIR="$PROJECT_DIR/venv"
WSGI_MODULE="$SITE_NAME.wsgi"
SOCKET_PATH="/run/$SERVICE_NAME.sock"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
LOG_DIR="/var/log/gunicorn/$SITE_NAME"

# 1. Créer le dossier log s’il n’existe pas
mkdir -p "$LOG_DIR"
chown www-data:www-data "$LOG_DIR"

# 2. Créer le fichier systemd pour gunicorn
echo "⚙️  Création du fichier systemd : $SERVICE_FILE"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=gunicorn daemon for $SITE_NAME
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$PROJECT_DIR
ExecStart=$VENV_DIR/bin/gunicorn \\
          --workers 3 \\
          --bind unix:$SOCKET_PATH \\
          --access-logfile $LOG_DIR/access.log \\
          --error-logfile $LOG_DIR/error.log \\
          $WSGI_MODULE:application

[Install]
WantedBy=multi-user.target
EOF

# 3. Démarrer et activer le service
echo "🚀 Démarrage du service Gunicorn..."
systemctl daemon-reload
systemctl start "$SERVICE_NAME"
systemctl enable "$SERVICE_NAME"

# 4. Vérification du statut
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "✅ Gunicorn fonctionne pour $SITE_NAME (socket : $SOCKET_PATH)"
    echo "📄 Logs : $LOG_DIR"
else
    echo "❌ Le service Gunicorn ne s’est pas lancé correctement."
    journalctl -u "$SERVICE_NAME" --no-pager | tail -n 20
    exit 1
fi
