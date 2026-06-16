#!/usr/bin/env bash
# Génération de trafic vers l'application HTTP.
# Usage : ./generate-traffic.sh [APP_URL]
# Exemple : ./generate-traffic.sh http://localhost:8080

set -euo pipefail

APP_URL="${1:-http://localhost:8080}"

echo "Génération de trafic vers $APP_URL"
echo "Appuyez sur Ctrl+C pour arrêter."
echo ""

# Modes de trafic
MODE="${2:-mixed}"

send_2xx() {
    curl -sf -o /dev/null "$APP_URL/hello"
    curl -sf -o /dev/null "$APP_URL/work"
    curl -sf -o /dev/null "$APP_URL/work"
    curl -sf -o /dev/null "$APP_URL/work"
}

send_4xx() {
    curl -sf -o /dev/null "$APP_URL/not-found" || true
}

send_5xx() {
    curl -sf -o /dev/null "$APP_URL/error" || true
}

case "$MODE" in
  "5xx-burst")
    echo "Mode : rafale 5xx (déclenche l'alerte HighHTTP5xxRate)"
    for i in $(seq 1 20); do
      send_5xx
      echo -n "."
    done
    echo ""
    echo "20 erreurs 5xx envoyées. Attendre ~1 minute pour voir l'alerte dans Prometheus."
    ;;

  "kill-alertmanager")
    echo "Mode : test d'alerte AlertmanagerUnavailableInK8s"
    echo "Mise à l'échelle du déploiement alertmanager à 0..."
    kubectl scale deployment alertmanager -n monitoring --replicas=0
    echo "Attendre ~1 minute, puis vérifier l'alerte dans Prometheus."
    echo "Pour restaurer : kubectl scale deployment alertmanager -n monitoring --replicas=1"
    ;;

  "kill-app")
    echo "Mode : test d'alerte AppDown"
    echo "Mise à l'échelle du déploiement app à 0..."
    kubectl scale deployment app -n default --replicas=0
    echo "Attendre ~1 minute, puis vérifier l'alerte dans Prometheus."
    echo "Pour restaurer : kubectl scale deployment app -n default --replicas=1"
    ;;

  "high-error-ratio")
    echo "Mode : taux d'erreur élevé (déclenche HighAppErrorRatio)"
    while true; do
      send_5xx
      send_5xx
      send_5xx
      send_4xx
      send_2xx
      sleep 0.2
    done
    ;;

  "mixed"|*)
    echo "Mode : trafic mixte (2xx, 4xx, 5xx)"
    COUNTER=0
    while true; do
      COUNTER=$((COUNTER + 1))

      # 60% 2xx
      send_2xx

      # 20% 4xx
      send_4xx

      # 20% 5xx (1 toutes les 5 itérations)
      if (( COUNTER % 5 == 0 )); then
        send_5xx
      fi

      printf "\rItération %d" "$COUNTER"
      sleep 0.5
    done
    ;;
esac
