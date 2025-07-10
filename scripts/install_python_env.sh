#!/bin/bash

echo "🐍 [install_python_env.sh] Installation de l’environnement Python..."

PROJECT_DIR="$BASE_DIR/$SITE_NAME"
VENV_DIR="$PROJECT_DIR/venv"

# 1. Création du dossier projet si non présent (sécurité)
mkdir -p "$PROJECT_DIR"

# 2. Créer l’environnement virtuel
if [[ ! -d "$VENV_DIR" ]]; then
    echo "📦 Création de l’environnement virtuel..."
    python3 -m venv "$VENV_DIR"
else
    echo "ℹ️ Environnement virtuel déjà existant."
fi

# 3. Activer le venv
source "$VENV_DIR/bin/activate"

# 4. Upgrade pip
echo "⬆️ Mise à jour de pip..."
pip install --upgrade pip

# 5. Installer les paquets nécessaires
echo "📥 Installation des dépendances Python..."
pip install django gunicorn psycopg2-binary python-dotenv

echo "✅ Environnement Python prêt dans $VENV_DIR"
