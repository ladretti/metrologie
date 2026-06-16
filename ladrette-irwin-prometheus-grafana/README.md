# ladrette-irwin — Prometheus & Grafana

Stack d'observabilité complète déployée sur un cluster Kubernetes local (kind) sans Helm ni Prometheus Operator.

## Structure du projet

```
ladrette-irwin-prometheus-grafana/
├── app/                        # Application HTTP instrumentée (Go)
│   ├── main.go
│   ├── go.mod
│   └── Dockerfile
├── manifests/
│   ├── namespace.yaml
│   ├── prometheus/             # Prometheus + RBAC + règles d'alerte
│   ├── alertmanager/
│   ├── node-exporter/
│   ├── kube-state-metrics/
│   ├── grafana/                # Grafana + provisioning automatique
│   └── app/                   # Application HTTP
├── grafana/
│   └── dashboard.json         # Export du dashboard
├── kind-config.yaml
├── generate-traffic.sh
└── README.md
```

---

## 1. Prérequis

- [`kind`](https://kind.sigs.k8s.io/) ≥ 0.23
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/) ≥ 1.28
- [`docker`](https://docs.docker.com/engine/install/) ≥ 24
- `curl` (pour la génération de trafic)

---

## 2. Construction de l'image de l'application

### Option A — Chargement local avec kind (recommandé pour le TP)

```bash
# Construire l'image
docker build -t prometheus-app:1.0.0 ./app

# Charger dans le cluster kind (après création du cluster)
kind load docker-image prometheus-app:1.0.0 --name monitoring

# Mettre à jour manifests/app/deployment.yaml :
# image: prometheus-app:1.0.0
# imagePullPolicy: Never
```

### Option B — Docker Hub

```bash
DOCKER_USER=ladrette-irwin   # remplacer par votre username Docker Hub

docker build -t $DOCKER_USER/prometheus-app:1.0.0 ./app
docker push $DOCKER_USER/prometheus-app:1.0.0

# L'image dans manifests/app/deployment.yaml est déjà :
# image: ladrette-irwin/prometheus-app:1.0.0
```

**Image utilisée :** `ladrette-irwin/prometheus-app:1.0.0`
**Tag figé :** `1.0.0` — aucun tag `latest` utilisé.

---

## 3. Déploiement

### 3.1 Créer le cluster kind

```bash
kind create cluster --config kind-config.yaml
kubectl cluster-info --context kind-monitoring
```

### 3.2 (Option A uniquement) Charger l'image

```bash
kind load docker-image prometheus-app:1.0.0 --name monitoring
```

Si vous avez choisi l'option A, modifiez `manifests/app/deployment.yaml` :
```yaml
image: prometheus-app:1.0.0
imagePullPolicy: Never
```

### 3.3 Appliquer les manifests

```bash
# Namespace
kubectl apply -f manifests/namespace.yaml

# Prometheus (RBAC + config + déploiement)
kubectl apply -f manifests/prometheus/

# Alertmanager
kubectl apply -f manifests/alertmanager/

# node-exporter
kubectl apply -f manifests/node-exporter/

# kube-state-metrics
kubectl apply -f manifests/kube-state-metrics/

# Grafana
kubectl apply -f manifests/grafana/

# Application HTTP
kubectl apply -f manifests/app/
```

### 3.4 Vérifier que tout est Running

```bash
kubectl get pods -n monitoring
kubectl get pods -n default
```

Résultat attendu :

```
NAMESPACE    NAME                                  READY   STATUS
monitoring   alertmanager-xxx                      1/1     Running
monitoring   grafana-xxx                           1/1     Running
monitoring   kube-state-metrics-xxx                1/1     Running
monitoring   node-exporter-xxx                     1/1     Running
monitoring   prometheus-xxx                        1/1     Running
default      app-xxx                               1/1     Running
```

---

## 4. Accès aux interfaces

Ouvrir chaque port-forward dans un terminal séparé :

```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Application HTTP
kubectl port-forward -n default svc/app 8080:8080
```

| Interface    | URL                        | Identifiants    |
|-------------|----------------------------|-----------------|
| Prometheus  | http://localhost:9090      | —               |
| Alertmanager| http://localhost:9093      | —               |
| Grafana     | http://localhost:3000      | admin / admin   |
| Application | http://localhost:8080      | —               |

---

## 5. Génération de trafic

Le script `generate-traffic.sh` supporte plusieurs modes :

```bash
# Trafic mixte (2xx / 4xx / 5xx) — mode par défaut
./generate-traffic.sh http://localhost:8080

# Rafale de 5xx pour déclencher l'alerte HighHTTP5xxRate
./generate-traffic.sh http://localhost:8080 5xx-burst

# Taux d'erreur élevé pour déclencher HighAppErrorRatio
./generate-traffic.sh http://localhost:8080 high-error-ratio
```

### Endpoints disponibles

| Endpoint       | Code retourné | Description                          |
|---------------|---------------|--------------------------------------|
| `GET /hello`   | 200           | Réponse simple 2xx                   |
| `GET /work`    | 200           | Traite N items (métrique métier)     |
| `GET /not-found` | 404         | Erreur client 4xx                    |
| `GET /error`   | 500           | Erreur serveur 5xx                   |
| `GET /metrics` | 200           | Métriques Prometheus                 |
| `GET /health`  | 200           | Liveness/readiness probe             |

---

## 6. Instrumentation de l'application

### Métriques exposées

| Métrique | Type | Labels | Description |
|---------|------|--------|-------------|
| `http_requests_total` | Counter | `method`, `path`, `status` | Compteur total de requêtes HTTP |
| `http_request_duration_seconds` | Histogram | `method`, `path` | Distribution de latence |
| `app_items_processed_total` | Counter | — | Items traités (métrique métier) |
| `app_processing_errors_total` | Counter | — | Erreurs de traitement interne |

### Choix d'instrumentation

- **`http_requests_total`** avec le label `status` (code HTTP exact) permet de filtrer par famille (`status=~"2.."`) dans PromQL et Grafana.
- **`http_request_duration_seconds`** (histogram) permet de calculer des percentiles (p50, p95, p99) avec `histogram_quantile`.
- **`app_items_processed_total`** simule une métrique fonctionnelle : chaque appel à `/work` traite entre 1 et 10 items aléatoirement. Ce débit reflète l'activité réelle du service.
- **`app_processing_errors_total`** comptabilise les erreurs internes (déclenchées par `/error`), distinctement du compteur HTTP.

---

## 7. Requêtes PromQL principales

### Dashboard Grafana

```promql
# Panel A — Erreurs 5xx sur les 5 dernières minutes
sum(increase(http_requests_total{status=~"5.."}[5m]))

# Panel B — Erreurs 4xx sur les 5 dernières minutes
sum(increase(http_requests_total{status=~"4.."}[5m]))

# Panel C — Trafic par famille (req/s, fenêtre 1m)
sum(rate(http_requests_total{status=~"2.."}[1m]))   # 2xx
sum(rate(http_requests_total{status=~"4.."}[1m]))   # 4xx
sum(rate(http_requests_total{status=~"5.."}[1m]))   # 5xx

# Panel D — Répartition des réponses
sum(increase(http_requests_total{status=~"2.."}[5m]))
sum(increase(http_requests_total{status=~"4.."}[5m]))
sum(increase(http_requests_total{status=~"5.."}[5m]))

# Panel E — Items traités par l'application
rate(app_items_processed_total[1m])
rate(app_processing_errors_total[1m])
```

### Alertes

```promql
# Alerte 1 — Composant indisponible (scraping échoue)
up{job="prometheus"} == 0
up{job="alertmanager"} == 0
up{job="grafana"} == 0
up{job="node-exporter"} == 0
up{job="kube-state-metrics"} == 0
up{job="app"} == 0

# Alerte 2 — Trop d'erreurs 5xx (seuil : 5 en 5 minutes)
sum(increase(http_requests_total{status=~"5.."}[5m])) > 5

# Alerte 3 — Alertmanager indisponible dans Kubernetes
kube_deployment_status_replicas_available{namespace="monitoring", deployment="alertmanager"} == 0

# Alerte 4 — Taux d'erreur élevé (>30% du trafic)
sum(rate(http_requests_total{status=~"[45].."}[5m]))
/ sum(rate(http_requests_total[5m])) > 0.3
```

---

## 8. Seuil X pour l'alerte 5xx

**Valeur choisie : X = 5 erreurs sur 5 minutes.**

**Justification :** Dans le contexte d'un service de démonstration à faible charge, une erreur 5xx est toujours anormale. Fixer X = 5 permet :
- D'éviter les faux positifs sur une unique erreur transitoire (retry réseau, redémarrage de pod).
- De détecter rapidement un dysfonctionnement systémique (boucle d'erreurs, endpoint cassé).
- De rester cohérent avec la fenêtre de 5 minutes : cela représente 1 erreur/minute, ce qui est significatif pour un service sain.

---

## 9. Tests des alertes

### Alerte 1 — Composant indisponible (ex : app)

```bash
# Provoquer l'alerte
kubectl scale deployment app -n default --replicas=0

# Attendre ~1 minute, puis vérifier dans Prometheus :
# http://localhost:9090/alerts → AppDown = FIRING

# Restaurer
kubectl scale deployment app -n default --replicas=1
```

> Note : l'alerte `up{job="app"} == 0` se déclenche quand le pod existe mais son scraping échoue (CrashLoopBackOff, endpoint /metrics cassé). Si le déploiement est à 0 replicas, la métrique `up` disparaît. Dans ce cas, observer dans Prometheus que `up{job="app"}` n'existe plus.

### Alerte 2 — Trop d'erreurs 5xx

```bash
# Envoyer une rafale de 5xx (> 5 en moins d'une minute)
./generate-traffic.sh http://localhost:8080 5xx-burst

# Vérifier dans Prometheus après ~1 minute :
# http://localhost:9090/alerts → HighHTTP5xxRate = FIRING

# Vérifier dans Alertmanager :
# http://localhost:9093
```

### Alerte 3 — Alertmanager indisponible dans Kubernetes

```bash
# Mettre Alertmanager à 0 replica
kubectl scale deployment alertmanager -n monitoring --replicas=0

# Attendre ~1 minute, vérifier dans Prometheus :
# http://localhost:9090/alerts → AlertmanagerUnavailableInK8s = FIRING
# (basé sur kube_deployment_status_replicas_available)

# Restaurer
kubectl scale deployment alertmanager -n monitoring --replicas=1
```

### Alerte 4 — Taux d'erreur élevé (HighAppErrorRatio)

```bash
# Générer un trafic majoritairement en erreur
./generate-traffic.sh http://localhost:8080 high-error-ratio

# Attendre ~2 minutes (for: 2m dans la règle), puis vérifier :
# http://localhost:9090/alerts → HighAppErrorRatio = FIRING
```

---

## 10. Découverte automatique des cibles

Prometheus découvre les cibles via deux mécanismes :

1. **`kubernetes-pods`** (rôle `pod`) : découvre les pods annotés avec `prometheus.io/scrape: "true"`. L'application HTTP utilise ce mécanisme (namespace `default`).

2. **Endpoint discovery** (rôle `endpoints`) : utilisé pour tous les composants du namespace `monitoring` (alertmanager, node-exporter, kube-state-metrics, grafana), filtrés par nom de service.

Vérifier les cibles dans Prometheus : http://localhost:9090/targets

---

## 11. Hypothèses et limites

- **Alertmanager** est configuré avec le receiver `null` (pas d'email/Slack). Dans un environnement réel, configurer un webhook ou un SMTP.
- **node-exporter** utilise `hostNetwork: true` et `hostPID: true` pour accéder aux métriques du nœud. Dans kind, le "nœud" est un conteneur Docker — les métriques reflètent le système hôte.
- **Stockage** : Prometheus et Grafana utilisent `emptyDir` (données perdues au redémarrage du pod). Pour persister les données, utiliser un PersistentVolumeClaim.
- **Sécurité** : le mot de passe Grafana (`admin/admin`) est en clair dans le manifest. Utiliser un Secret Kubernetes en production.
- **HTTPS** : non configuré. L'accès se fait via `kubectl port-forward` en HTTP.
- **Alerte AppDown** : si le déploiement est à 0 replicas, la métrique `up{job="app"}` disparaît (pas de pod à scraper). L'alerte `up == 0` ne se déclenche pas dans ce cas. Pour une détection plus robuste, utiliser `kube_deployment_status_replicas_available == 0` (couvert par l'alerte 3 pour Alertmanager).
