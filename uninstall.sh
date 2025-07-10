#!/bin/bash

# ───────────── CONFIG & VALIDATION ─────────────

SITE_NAME=$1

if [[ -z "$SITE_NAME" ]]; then
  echo "❌ Usage : sudo ./uninstall.sh <nom_du_site>"
  exit 1
fi

PROJECT_DIR="/var/www/$SITE_NAME"
GUNICORN_SERVICE="gunicorn-$SITE_NAME"
NGINX_CONF="/etc/nginx/sites-available/$SITE_NAME"
NGINX_LINK="/etc/nginx/sites-enabled/$SITE_NAME"
SOCKET="/run/$GUNICORN_SERVICE.sock"
LOG_NGINX="/var/log/nginx/$SITE_NAME"
LOG_GUNICORN="/var/log/gunicorn/$SITE_NAME"

echo "⚠️  Ce script va supprimer définitivement le site : $SITE_NAME"
read -p "Confirmer la suppression complète ? (y/n) : " confirm
[[ "$confirm" != "y" ]] && echo "❌ Annulé." && exit 0

# ───────────── SUPPRESSION ─────────────

echo "🗑️ Suppression du projet Django..."
rm -rf "$PROJECT_DIR"

echo "🛑 Arrêt et suppression du service Gunicorn..."
systemctl stop "$GUNICORN_SERVICE"
systemctl disable "$GUNICORN_SERVICE"
rm -f "/etc/systemd/system/$GUNICORN_SERVICE.service"

echo "🌐 Suppression de la config Nginx..."
rm -f "$NGINX_CONF"
rm -f "$NGINX_LINK"

echo "📁 Suppression des sockets et logs..."
rm -f "$SOCKET"
rm -rf "$LOG_NGINX"
rm -rf "$LOG_GUNICORN"

echo "🔁 Rechargement systemd et Nginx..."
systemctl daemon-reload
systemctl reload nginx

echo "✅ Le site $SITE_NAME a été supprimé avec succès."
