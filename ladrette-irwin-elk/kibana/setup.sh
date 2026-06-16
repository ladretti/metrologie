#!/usr/bin/env bash
# Configure Kibana : data views + import des dashboards.
# Usage : ./kibana/setup.sh [KIBANA_URL]
# Attendre que Kibana soit prêt avant de lancer ce script.

set -euo pipefail

KIBANA="${1:-http://localhost:5601}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

wait_kibana() {
  echo "Attente que Kibana soit prêt..."
  for i in $(seq 1 30); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$KIBANA/api/status" 2>/dev/null || echo "000")
    if [ "$STATUS" = "200" ]; then
      echo "Kibana est prêt."
      return 0
    fi
    echo "  Tentative $i/30... (HTTP $STATUS)"
    sleep 10
  done
  echo "ERREUR : Kibana ne répond pas après 5 minutes."
  exit 1
}

create_data_view() {
  local title="$1"
  local id="$2"
  local time_field="${3:-@timestamp}"

  echo "Création de la data view : $title"
  curl -s -X POST "$KIBANA/api/data_views/data_view" \
    -H "kbn-xsrf: true" \
    -H "Content-Type: application/json" \
    -d "{
      \"data_view\": {
        \"id\": \"$id\",
        \"title\": \"$title\",
        \"timeFieldName\": \"$time_field\"
      },
      \"override\": true
    }" | python3 -c "import sys,json; d=json.load(sys.stdin); print('  OK:', d.get('data_view',{}).get('title','?'))" 2>/dev/null || echo "  (déjà existante)"
}

import_objects() {
  local file="$1"
  echo "Import : $file"
  curl -s -X POST "$KIBANA/api/saved_objects/_import?overwrite=true" \
    -H "kbn-xsrf: true" \
    --form "file=@$file" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('  success:', d.get('successCount',0), '/ errors:', len(d.get('errors',[])))" 2>/dev/null
}

wait_kibana

echo ""
echo "=== Création des data views ==="
create_data_view "app-logs-*"     "app-logs-data-view"       "@timestamp"
create_data_view "air-quality-*"  "air-quality-data-view"    "@timestamp"

echo ""
echo "=== Import des dashboards ==="
import_objects "$SCRIPT_DIR/dashboard-developer.ndjson"
import_objects "$SCRIPT_DIR/dashboard-support.ndjson"

echo ""
echo "Setup terminé. Ouvrir Kibana : $KIBANA"
echo "  Stack Management > Data Views  → vérifier les deux data views"
echo "  Dashboards                     → 'Developer Dashboard' et 'Support Dashboard'"
