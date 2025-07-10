#!/bin/bash

echo "🛢️ [install_postgres.sh] Vérification de PostgreSQL..."

# ───────────────────────────────────────────────
# 1. Vérifie si PostgreSQL est installé
# ───────────────────────────────────────────────
if ! command -v psql >/dev/null 2>&1; then
    echo "❌ PostgreSQL n’est pas installé (psql introuvable)."
    echo "👉 Vérifiez le script check_dependencies.sh"
    exit 1
fi

# ───────────────────────────────────────────────
# 2. Vérifie si le service PostgreSQL est actif
# ───────────────────────────────────────────────
if systemctl is-active --quiet postgresql; then
    echo "✅ PostgreSQL est actif"
else
    echo "🔄 PostgreSQL est installé mais inactif → démarrage..."
    systemctl start postgresql
fi

# ───────────────────────────────────────────────
# 3. Active le service PostgreSQL au démarrage
# ───────────────────────────────────────────────
systemctl enable postgresql

# ───────────────────────────────────────────────
# 4. Vérifie que le cluster principal est opérationnel
# ───────────────────────────────────────────────
if ! sudo -u postgres psql -c '\l' >/dev/null 2>&1; then
    echo "⚠️ PostgreSQL est actif, mais aucun cluster détecté ou problème d’accès."
    echo "🔎 Essayez de réinitialiser le cluster manuellement ou vérifier l'installation."
    exit 1
fi

echo "✅ PostgreSQL est prêt à être utilisé."
