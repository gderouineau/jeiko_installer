#!/bin/bash

### ─────────────────────────────────────────────
### JEIKO INSTALLER v1.0
### Installe un projet Django complet avec PostgreSQL, Gunicorn et Nginx
### Auteur : Guillaume Derouineau
### ─────────────────────────────────────────────

set -e
trap 'echo "❌ Une erreur est survenue à la ligne $LINENO. Voir le log $LOG_FILE"; exit 1' ERR

VERSION="1.0"
echo "📦 JEIKO INSTALLER v$VERSION"

# Vérifie que le script est lancé avec sudo
if [[ $EUID -ne 0 ]]; then
   echo "❌ Ce script doit être exécuté avec sudo : sudo ./install.sh"
   exit 1
fi

# Création du dossier de logs
BASE_DIR=$(pwd)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$BASE_DIR/logs/install_log_$TIMESTAMP.log"
mkdir -p "$BASE_DIR/logs"

# Demande les informations nécessaires
read -p "▶️  Nom du site (ex: monsite) : " SITE_NAME
[[ ! "$SITE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] && echo "❌ Nom invalide (lettres, chiffres, - ou _ uniquement)" && exit 1

read -p "▶️  Nom de domaine (ex: monsite.fr) : " DOMAIN_NAME
[[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9.-]+\.[a-z]{2,}$ ]] && echo "❌ Domaine invalide" && exit 1

read -p "▶️  Nom de la base PostgreSQL : " DB_NAME
read -p "▶️  Nom de l'utilisateur PostgreSQL : " DB_USER
read -sp "▶️  Mot de passe PostgreSQL : " DB_PASS; echo

read -p "▶️  Nom du superuser Django : " DJANGO_SUPERUSER
read -p "▶️  Email du superuser Django : " DJANGO_SUPEREMAIL
read -sp "▶️  Mot de passe superuser Django : " DJANGO_SUPERPASS; echo

read -p "▶️  Activer HTTPS avec Let's Encrypt ? (y/n) : " ENABLE_SSL
ENABLE_SSL=${ENABLE_SSL,,}  # minuscule

# Affiche un résumé
echo "──────────── RÉCAPITULATIF ────────────"
echo "🧩 Nom du site       : $SITE_NAME"
echo "🌍 Domaine           : $DOMAIN_NAME"
echo "🛢️  Base PostgreSQL   : $DB_NAME"
echo "👤 Utilisateur DB    : $DB_USER"
echo "🔐 Superuser Django  : $DJANGO_SUPERUSER <$DJANGO_SUPEREMAIL>"
echo "🔒 Let's Encrypt     : $ENABLE_SSL"
echo "📁 Dossier projet    : $BASE_DIR/$SITE_NAME"
echo "───────────────────────────────────────"
read -p "Confirmer l'installation ? (y/n) : " confirm
[[ "$confirm" != "y" ]] && echo "Installation annulée." && exit 0

# Exporte les variables pour les sous-scripts
export BASE_DIR
export SITE_NAME
export DOMAIN_NAME
export DB_NAME
export DB_USER
export DB_PASS
export DJANGO_SUPERUSER
export DJANGO_SUPEREMAIL
export DJANGO_SUPERPASS
export ENABLE_SSL
export LOG_FILE

# Enregistre les infos dans un .env pour la mise à jour future
cat > "$BASE_DIR/.env.$SITE_NAME" <<EOF
# Fichier généré par install.sh
SITE_NAME="$SITE_NAME"
DOMAIN_NAME="$DOMAIN_NAME"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
DJANGO_SUPERUSER="$DJANGO_SUPERUSER"
DJANGO_SUPEREMAIL="$DJANGO_SUPEREMAIL"
DJANGO_SUPERPASS="$DJANGO_SUPERPASS"
ENABLE_SSL="$ENABLE_SSL"
EOF

# Lancement des scripts d’installation
echo "🚀 Installation en cours... Voir $LOG_FILE"
./scripts/check_dependencies.sh      | tee -a "$LOG_FILE"
./scripts/install_postgres.sh        | tee -a "$LOG_FILE"
./scripts/setup_database.sh          | tee -a "$LOG_FILE"
./scripts/install_python_env.sh      | tee -a "$LOG_FILE"
./scripts/install_jeiko_package.sh   | tee -a "$LOG_FILE"
./scripts/configure_django.sh        | tee -a "$LOG_FILE"
./scripts/configure_gunicorn.sh      | tee -a "$LOG_FILE"
./scripts/configure_nginx.sh         | tee -a "$LOG_FILE"
./scripts/finalize.sh                | tee -a "$LOG_FILE"

# Fin
echo ""
echo "✅ Installation terminée avec succès !"
echo "🌐 Site : https://$DOMAIN_NAME"
echo "🔐 Admin Django : https://$DOMAIN_NAME/admin/"
echo "📄 Détails : $LOG_FILE"
