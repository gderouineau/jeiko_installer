#!/bin/bash

echo "📦 [install_jeiko_package.sh] Installation du package JEIKO..."

# Chemins
PROJECT_DIR="$BASE_DIR/$SITE_NAME"
VENV_DIR="$PROJECT_DIR/venv"
TMP_ZIP="/tmp/jeiko_latest.zip"
ZIP_URL="https://github.com/tonuser/jeiko/releases/download/v1.0/jeiko.zip"

# 1. Activer le venv
source "$VENV_DIR/bin/activate"

# 2. Télécharger le zip depuis GitHub (release ou autre lien direct)
echo "🔽 Téléchargement du package depuis GitHub..."
curl -L "$ZIP_URL" -o "$TMP_ZIP"

# 3. Extraire dans le site-packages du venv
SITE_PACKAGES=$(python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")

echo "📂 Extraction dans $SITE_PACKAGES..."
unzip -o "$TMP_ZIP" -d "$SITE_PACKAGES"

# 4. Installer requirements.txt depuis le zip (si présent)
REQUIREMENTS_FILE=$(unzip -l "$TMP_ZIP" | grep "requirements.txt" | awk '{print $4}')
if [[ -n "$REQUIREMENTS_FILE" ]]; then
    echo "📥 Installation des dépendances du package..."
    unzip -p "$TMP_ZIP" "$REQUIREMENTS_FILE" > /tmp/requirements_jeiko.txt
    pip install -r /tmp/requirements_jeiko.txt
else
    echo "⚠️ Aucun requirements.txt trouvé dans le zip."
fi

# 5. Test d'import (facultatif)
if python -c "import jeiko" &>/dev/null; then
    echo "✅ Package JEIKO installé et détecté"
else
    echo "❌ Le package JEIKO ne semble pas importable. Vérifiez le contenu du zip."
    exit 1
fi
