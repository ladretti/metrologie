# ladrette-irwin — ELK Stack

Stack d'ingestion et de visualisation de logs déployée sur Kubernetes local (kind) sans Helm.

## Structure

```
ladrette-irwin-elk/
├── app/                        # Application HTTP avec logs JSON structurés (Go)
├── air-quality-importer/       # Image Logstash custom pour import CSV Air Quality
├── datasets/
│   └── Air_Quality.log
├── manifests/
│   ├── namespace.yaml
│   ├── elasticsearch/
│   ├── kibana/
│   ├── logstash/
│   ├── filebeat/
│   ├── air-quality-job/
│   └── app/
├── kibana/
│   ├── setup.sh
│   ├── dashboard-developer.ndjson
│   └── dashboard-support.ndjson
├── kind-config.yaml
└── generate-logs.sh
```

---

## 1. Prérequis

- `kind` ≥ 0.23, `kubectl`, `docker`, `curl`, `python3`

---

## 2. Construction des images

### Application HTTP

```bash
docker build -t ladrette-irwin/elk-app:1.0.0 ./app
```

**Image :** `ladrette-irwin/elk-app:1.0.0` — tag figé `1.0.0`

### Importeur Air Quality

```bash
# Build depuis la racine du projet (contexte nécessaire pour datasets/)
docker build -t ladrette-irwin/air-quality-importer:1.0.0 \
  -f air-quality-importer/Dockerfile .
```

**Image :** `ladrette-irwin/air-quality-importer:1.0.0` — tag figé `1.0.0`

---

## 3. Déploiement

### 3.1 Cluster kind

```bash
kind create cluster --config kind-config.yaml
```

### 3.2 Chargement des images locales

```bash
kind load docker-image ladrette-irwin/elk-app:1.0.0           --name elk
kind load docker-image ladrette-irwin/air-quality-importer:1.0.0 --name elk
```

### 3.3 Déploiement de la stack

```bash
kubectl apply -f manifests/namespace.yaml

# Elasticsearch en premier (les autres en dépendent)
kubectl apply -f manifests/elasticsearch/
kubectl wait --for=condition=ready pod -n logging -l app=elasticsearch --timeout=180s

# Reste de la stack
kubectl apply -f manifests/kibana/
kubectl apply -f manifests/logstash/
kubectl apply -f manifests/filebeat/
kubectl apply -f manifests/app/
```

### 3.4 Import Air Quality

```bash
# Lancer le Job d'import (attend qu'Elasticsearch soit prêt)
kubectl apply -f manifests/air-quality-job/job.yaml

# Suivre la progression
kubectl logs -n logging -l job-name=air-quality-importer -f
```

### 3.5 Vérification

```bash
kubectl get pods -n logging
kubectl get pods -n default
```

Résultat attendu :

```
NAMESPACE  NAME                          READY   STATUS
logging    elasticsearch-xxx             1/1     Running
logging    kibana-xxx                    1/1     Running
logging    logstash-xxx                  1/1     Running
logging    filebeat-xxx                  1/1     Running
logging    air-quality-importer-xxx      0/1     Completed
default    app-xxx                       1/1     Running
```

---

## 4. Accès aux interfaces

| Interface | URL                    |
|-----------|------------------------|
| Kibana    | http://localhost:5601  |
| App       | http://localhost:8080  |

Ports exposés directement via `extraPortMappings` kind — pas de port-forward nécessaire.

---

## 5. Configuration Kibana

```bash
chmod +x kibana/setup.sh
./kibana/setup.sh http://localhost:5601
```

Ce script :
1. Crée la data view `app-logs-*` (champ temporel : `@timestamp`)
2. Crée la data view `air-quality-*` (champ temporel : `@timestamp`)
3. Importe les dashboards Developer et Support

---

## 6. Génération de logs

```bash
# Trafic mixte (défaut)
./generate-logs.sh http://localhost:8080

# Uniquement nominal (2xx)
./generate-logs.sh http://localhost:8080 nominal

# Uniquement erreurs (4xx + 5xx)
./generate-logs.sh http://localhost:8080 errors

# Rafale 5xx
./generate-logs.sh http://localhost:8080 burst-5xx

# Test recherche par request_id
./generate-logs.sh http://localhost:8080 search-by-id
```

### Endpoints disponibles

| Endpoint     | Code  | Description                         |
|-------------|-------|-------------------------------------|
| GET /hello   | 200   | Réponse nominale                    |
| GET /work    | 200   | Traitement d'items (log métier)     |
| GET /not-found | 404 | Erreur client                       |
| GET /error   | 500   | Erreur serveur                      |
| GET /health  | 200   | Sonde readiness                     |

---

## 7. Structuration des logs

L'application utilise `log/slog` (stdlib Go 1.21+) avec le handler JSON.

### Format d'un log de requête HTTP

```json
{
  "time": "2026-06-16T10:00:00.123456789Z",
  "level": "INFO",
  "msg": "request completed",
  "request_id": "a1b2c3d4e5f6g7h8",
  "method": "GET",
  "path": "/hello",
  "status": 200,
  "duration_ms": 3
}
```

### Niveaux de log

| Niveau  | Condition            |
|---------|----------------------|
| `INFO`  | status 2xx           |
| `WARN`  | status 4xx           |
| `ERROR` | status 5xx           |
| `INFO`  | événement métier     |

### Log d'événement métier (endpoint /work)

```json
{
  "time": "2026-06-16T10:00:00Z",
  "level": "INFO",
  "msg": "items processed",
  "request_id": "b1c2d3e4f5g6h7i8",
  "event_type": "processing",
  "item_count": 7
}
```

### Chaîne d'ingestion

```
App (stdout JSON)
  → Filebeat (container input + kubernetes metadata)
  → Logstash (filtre app label, parse JSON, date filter)
  → Elasticsearch index app-logs-YYYY.MM.dd
```

Logstash filtre les pods par `kubernetes.labels.app == "app"`, les autres pods sont ignorés.

---

## 8. Recherches Kibana principales

Toutes les recherches s'effectuent dans **Discover** avec la data view `app-logs-*`.

### Recherche temporelle

Utiliser le sélecteur de temps en haut à droite (ex : Last 1 hour).

### Par niveau de log

```kql
level : "ERROR"
level : "WARN"
level : "INFO"
```

### Par route / action

```kql
path : "/error"
path : "/work"
```

### Par identifiant de requête

```kql
request_id : "a1b2c3d4e5f6g7h8"
```

(Copier un `request_id` depuis un log, puis rechercher)

### Sur les erreurs

```kql
level : "ERROR" OR level : "WARN"
status >= 400
status >= 500
```

### Combinée (exemple)

```kql
level : "ERROR" AND path : "/error"
```

---

## 9. Dashboards

### Developer Dashboard

Orienté investigation d'incident :
- Compteurs 5xx, 4xx, total requêtes
- Timeline des logs par niveau (bar stacked)
- Top routes en erreur (bar horizontal)
- Latence moyenne par route

### Support Dashboard

Orienté suivi fonctionnel :
- Requêtes réussies, incidents détectés, items traités
- Répartition des réponses par niveau (pie)
- Activité du service dans le temps (area chart)

---

## 10. Mini-TP Air Quality

### Import

L'import est automatique via le Job Kubernetes `air-quality-importer`. Il lit `/data/Air_Quality.log` (inclus dans l'image), parse le CSV et indexe dans `air-quality-YYYY`.

Pipeline Logstash : `air-quality-importer/pipeline/air-quality.conf`

### Data View

Créée automatiquement par `kibana/setup.sh` : `air-quality-*` avec `@timestamp` comme champ temporel.

### Champs disponibles

| Champ           | Type    | Description                |
|-----------------|---------|----------------------------|
| `@timestamp`    | date    | Date depuis `Start_Date`   |
| `name`          | string  | Polluant (Ozone, PM2.5…)   |
| `data_value`    | float   | Valeur mesurée             |
| `measure_info`  | string  | Unité (ppb, µg/m³…)        |
| `geo_place_name`| string  | Lieu (Bronx, Manhattan…)   |
| `geo_type_name` | string  | Type géo (Borough, CD)     |
| `time_period`   | string  | Saison/période             |

### Recherches Air Quality

```kql
# Pics de pollution O3 entre 2008 et 2012
name : "Ozone (O3)" AND @timestamp >= "2008-01-01" AND @timestamp <= "2012-12-31"

# Valeurs élevées d'un polluant sur une fenêtre temporelle
name : "Fine particles (PM 2.5)" AND data_value > 10 AND @timestamp >= "2010-01-01"

# Filtrer sur le Bronx
geo_place_name : "Bronx"
```

---

## 11. Hypothèses et limites

- **Elasticsearch** tourne en mode single-node avec `xpack.security.enabled: false` — adapté au TP, non recommandé en production.
- **Stockage** : `emptyDir` pour ES et Logstash — données perdues au redémarrage du pod. Utiliser un PVC en production.
- **Filtrage Filebeat** : seuls les pods avec `app: app` sont transmis à Elasticsearch. Les logs de la stack ELK elle-même ne sont pas ingérés (évite la boucle).
- **Air Quality** : le Job Logstash utilise `mode => "read"` pour lire le fichier une seule fois et s'arrêter.
- **Dashboards Kibana** : les NDJSON sont écrits manuellement et peuvent nécessiter un ajustement mineur selon la version de Kibana.
