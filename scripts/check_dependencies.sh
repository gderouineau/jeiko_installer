#!/bin/bash

echo "🔍 [check_dependencies.sh] Vérification des dépendances système..."

# ───────────────────────────────────────────────
# 1. Vérifier que le système est basé sur apt
# ───────────────────────────────────────────────
if ! command -v apt-get >/dev/null 2>&1; then
    echo "❌ Ce script nécessite un système Debian/Ubuntu (apt-get introuvable)"
    exit 1
fi

# ───────────────────────────────────────────────
# 2. Liste des paquets requis
# ───────────────────────────────────────────────
REQUIRED_PACKAGES=(
  curl
  unzip
  git
  nginx
  python3
  python3-venv
  python3-pip
  postgresql
  postgresql-contrib
)

NEED_UPDATE=false

# ───────────────────────────────────────────────
# 3. Vérifier et installer chaque paquet
# ───────────────────────────────────────────────
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        echo "📦 $pkg manquant : sera installé"
        NEED_UPDATE=true
    fi
done

# Mise à jour de la liste des paquets si besoin
if $NEED_UPDATE; then
    echo "🔄 Mise à jour des paquets (apt-get update)"
    apt-get update -y
fi

# Installation des paquets manquants
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        echo "🚀 Installation de $pkg..."
        apt-get install -y "$pkg"
    else
        echo "✅ $pkg est déjà installé"
    fi
done

# ───────────────────────────────────────────────
# 4. Vérification version minimale de Python (≥ 3.8)
# ───────────────────────────────────────────────
PY_VERSION=$(python3 -V 2>&1 | cut -d' ' -f2)
MIN_VERSION="3.8"
if [[ "$(printf '%s\n' "$MIN_VERSION" "$PY_VERSION" | sort -V | head -n1)" != "$MIN_VERSION" ]]; then
    echo "❌ Python $MIN_VERSION ou supérieur requis (actuel : $PY_VERSION)"
    exit 1
fi

echo "✅ Toutes les dépendances système sont présentes et à jour."
