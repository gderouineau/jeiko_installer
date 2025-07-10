#!/bin/bash

echo "🧱 [setup_database.sh] Création base et utilisateur PostgreSQL..."

# Vérifie si la base existe déjà
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
if [[ "$DB_EXISTS" == "1" ]]; then
    echo "ℹ️  La base '$DB_NAME' existe déjà. Aucune action."
else
    echo "🛢️  Création de la base '$DB_NAME'..."
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    echo "✅ Base créée."
fi

# Vérifie si l'utilisateur existe déjà
USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'")
if [[ "$USER_EXISTS" == "1" ]]; then
    echo "ℹ️  L'utilisateur '$DB_USER' existe déjà. Aucune action."
else
    echo "👤 Création de l'utilisateur '$DB_USER'..."
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    echo "✅ Utilisateur créé."
fi

# Applique la configuration recommandée
echo "⚙️  Configuration de l'utilisateur '$DB_USER'..."
sudo -u postgres psql <<EOF
ALTER ROLE $DB_USER SET client_encoding TO 'utf8';
ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $DB_USER SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF

echo "✅ Configuration terminée pour '$DB_NAME' et utilisateur '$DB_USER'."
