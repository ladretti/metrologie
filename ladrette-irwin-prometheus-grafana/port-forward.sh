#!/usr/bin/env bash
# Lance et maintient tous les port-forwards actifs.
# Usage : ./port-forward.sh
# Arrêt  : Ctrl+C

trap 'kill $(jobs -p) 2>/dev/null; exit 0' INT TERM

keep_forward() {
  local ns="$1" svc="$2" port="$3"
  while true; do
    kubectl port-forward -n "$ns" "svc/$svc" "$port:$port" 2>/dev/null
    sleep 2
  done
}

echo "Démarrage des port-forwards (Ctrl+C pour arrêter)..."
keep_forward monitoring prometheus   9090 &
keep_forward monitoring alertmanager 9093 &
keep_forward monitoring grafana      3000 &
keep_forward default   app           8080 &

echo ""
echo "  Prometheus  → http://localhost:9090"
echo "  Alertmanager→ http://localhost:9093"
echo "  Grafana     → http://localhost:3000  (admin/admin)"
echo "  App         → http://localhost:8080"
echo ""

wait
