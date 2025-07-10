#!/bin/bash

echo "🌐 [configure_nginx.sh] Configuration de Nginx..."

NGINX_CONF_PATH="/etc/nginx/sites-available/$SITE_NAME"
NGINX_ENABLED_PATH="/etc/nginx/sites-enabled/$SITE_NAME"
SOCKET_PATH="/run/gunicorn-$SITE_NAME.sock"
LOG_DIR="/var/log/nginx/$SITE_NAME"

mkdir -p "$LOG_DIR"

# 1. Création de la config de base
echo "⚙️  Création du fichier $NGINX_CONF_PATH"

cat > "$NGINX_CONF_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root $BASE_DIR/$SITE_NAME;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:$SOCKET_PATH;
    }

    client_max_body_size 20M;

    access_log $LOG_DIR/access.log;
    error_log $LOG_DIR/error.log;
}
EOF

# 2. Lien vers sites-enabled
if [[ ! -f "$NGINX_ENABLED_PATH" ]]; then
    ln -s "$NGINX_CONF_PATH" "$NGINX_ENABLED_PATH"
    echo "🔗 Lien créé vers sites-enabled"
else
    echo "ℹ️ Lien sites-enabled déjà présent"
fi

# 3. Restart Nginx
echo "🔁 Redémarrage de Nginx..."
systemctl restart nginx

# 4. Let's Encrypt SSL
if [[ "$ENABLE_SSL" == "y" ]]; then
    echo "🔒 Activation HTTPS avec Let's Encrypt..."
    apt-get install -y certbot python3-certbot-nginx

    certbot --nginx -d "$DOMAIN_NAME" -d "www.$DOMAIN_NAME" --non-interactive --agree-tos -m admin@$DOMAIN_NAME

    echo "🔁 Mise à jour de la config Nginx pour rediriger HTTP → HTTPS..."
    cat > "$NGINX_CONF_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    client_max_body_size 20M;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root $BASE_DIR/$SITE_NAME;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:$SOCKET_PATH;
    }

    access_log $LOG_DIR/access.log;
    error_log $LOG_DIR/error.log;
}
EOF

    echo "🔄 Reload Nginx avec HTTPS forcé..."
    nginx -t && systemctl reload nginx

    echo "🗓️  Installation du renouvellement auto des certificats (systemd)..."
    systemctl enable certbot.timer
    systemctl start certbot.timer
    echo "✅ Certificat SSL actif et auto-renouvelé."
else
    echo "🔓 HTTPS non activé (ENABLE_SSL != y)"
fi
