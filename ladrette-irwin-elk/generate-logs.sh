#!/usr/bin/env bash
# Génération de logs vers l'application HTTP.
# Usage : ./generate-logs.sh [APP_URL] [MODE]
# Modes : mixed (défaut) | errors | nominal | burst-5xx | search-by-id

set -euo pipefail

APP_URL="${1:-http://localhost:8080}"
MODE="${2:-mixed}"

echo "Génération de logs vers $APP_URL  (mode: $MODE)"
echo "Ctrl+C pour arrêter."
echo ""

case "$MODE" in
  "nominal")
    echo "Mode nominal — uniquement des 2xx"
    while true; do
      curl -sf -o /dev/null "$APP_URL/hello"
      curl -sf -o /dev/null "$APP_URL/work"
      curl -sf -o /dev/null "$APP_URL/work"
      printf "."
      sleep 0.3
    done
    ;;

  "errors")
    echo "Mode erreurs — mélange 4xx et 5xx"
    while true; do
      curl -sf -o /dev/null "$APP_URL/not-found" || true
      curl -sf -o /dev/null "$APP_URL/error"     || true
      curl -sf -o /dev/null "$APP_URL/not-found" || true
      printf "."
      sleep 0.3
    done
    ;;

  "burst-5xx")
    echo "Mode rafale 5xx (30 requêtes)"
    for i in $(seq 1 30); do
      curl -sf -o /dev/null "$APP_URL/error" || true
      printf "."
    done
    echo ""
    echo "Rafale terminée."
    ;;

  "search-by-id")
    echo "Mode identifiant de requête — envoi de 3 requêtes puis recherche dans Kibana"
    curl -sf -o /dev/null "$APP_URL/hello"
    curl -sf -o /dev/null "$APP_URL/work"
    curl -sf -o /dev/null "$APP_URL/error" || true
    echo ""
    echo "Logs envoyés. Dans Kibana Discover, filtrer par request_id."
    echo "Exemple KQL : path : \"/error\" AND level : \"ERROR\""
    ;;

  "mixed"|*)
    echo "Mode mixte — 2xx / 4xx / 5xx"
    COUNTER=0
    while true; do
      COUNTER=$((COUNTER + 1))
      curl -sf -o /dev/null "$APP_URL/hello"     2>/dev/null
      curl -sf -o /dev/null "$APP_URL/work"      2>/dev/null
      curl -sf -o /dev/null "$APP_URL/work"      2>/dev/null
      curl -sf -o /dev/null "$APP_URL/not-found" 2>/dev/null || true
      if (( COUNTER % 4 == 0 )); then
        curl -sf -o /dev/null "$APP_URL/error" 2>/dev/null || true
      fi
      printf "\rItération %d" "$COUNTER"
      sleep 0.5
    done
    ;;
esac
