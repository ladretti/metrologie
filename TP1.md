# TP Prometheus et Grafana

## Contexte

Vous travaillez sur une application HTTP de type microservice déployée dans Kubernetes. Votre objectif est de rendre cette application observable avec Prometheus, Alertmanager et Grafana, sans Helm et sans Prometheus Operator.

Le rendu doit démontrer que vous comprenez la chaîne complète : déploiement, exposition de métriques, collecte, visualisation et alerting.

Vous devez utiliser des manifests Kubernetes simples.

## Contraintes

- Le cluster local doit être créé avec `kind`.
- Le rendu ne doit pas être un export brut généré par Helm.
- Les composants doivent être déployés via vos propres manifests Kubernetes.
- Prometheus doit découvrir les cibles automatiquement depuis Kubernetes.
- Grafana doit utiliser Prometheus comme source de données.
- Alertmanager doit être intégré à la chaîne d'alerting.
- Vous devez fournir vos fichiers sources, pas seulement des captures d'écran.

## Composants obligatoires

Votre cluster doit contenir au minimum :

- Prometheus.
- Alertmanager.
- node-exporter.
- kube-state-metrics.
- Grafana.
- Une application HTTP instrumentée.

Vous êtes responsables du choix et de l'organisation des ressources Kubernetes nécessaires pour faire fonctionner ces composants.

Les manifests doivent utiliser les images suivantes :

| Composant | Image Docker obligatoire |
|---|---|
| Prometheus | `prom/prometheus:v3.5.3` |
| Alertmanager | `prom/alertmanager:v0.33.0` |
| node-exporter | `prom/node-exporter:v1.11.1` |
| kube-state-metrics | `registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.19.1` |
| Grafana | `grafana/grafana:13.0.2` |
| Application HTTP instrumentée | Image produite par votre groupe, avec tag figé et documenté |

## Application attendue

Vous devez développer une petite application HTTP dans le langage de votre choix.

Cette application doit exposer des métriques exploitables par Prometheus.

Elle doit permettre de produire du trafic HTTP comprenant au minimum :

- des réponses de la famille `2xx`,
- des réponses de la famille `4xx`,
- des réponses de la famille `5xx`.

Les métriques doivent permettre d'exploiter ces familles de codes HTTP dans Prometheus et Grafana.

L'application doit aussi exposer au moins une métrique spécifique à son propre comportement fonctionnel ou technique, autre que le simple comptage des codes HTTP.

Le correcteur doit pouvoir envoyer des requêtes HTTP ou HTTPS vers votre application, selon l'accès que vous documentez, puis observer l'effet de ces appels dans Prometheus et Grafana.

## Travail demandé

### 1. Cluster local

Créez un cluster Kubernetes local avec `kind`.

### 2. Stack de monitoring

Déployez l'ensemble des composants obligatoires avec des manifests Kubernetes.

Votre rendu doit pouvoir être rejoué sur un cluster vierge par le correcteur.

### 3. Collecte Prometheus

Prometheus doit collecter les métriques des composants obligatoires et de l'application.

Le correcteur doit pouvoir vérifier dans Prometheus que les cibles attendues sont découvertes et collectées.

### 4. Alertes

Vous devez définir des règles d'alerte Prometheus couvrant les cas suivants.

#### Alerte 1 : composant obligatoire indisponible

Une alerte doit permettre de détecter l'indisponibilité d'un composant obligatoire.

Les composants à couvrir sont :

- Prometheus.
- Alertmanager.
- Grafana.
- node-exporter.
- kube-state-metrics.
- Application HTTP instrumentée.

#### Alerte 2 : trop d'erreurs HTTP 5xx

Une alerte doit se déclencher si l'application produit plus de `X` erreurs HTTP de la famille `5xx` sur une fenêtre de 5 minutes.

Vous choisissez la valeur de `X` et vous la justifiez dans le `README.md`.

#### Alerte 3 : Alertmanager indisponible dans Kubernetes

Une alerte doit se déclencher si Alertmanager n'est plus correctement disponible dans le cluster.

Cette alerte est distincte de l'alerte de collecte Prometheus.

#### Alerte 4 : alerte propre à votre application

Définissez une alerte pertinente liée au comportement de votre application.

Cette alerte ne doit pas être une simple copie des alertes précédentes.

### 5. Génération de trafic

Vous devez fournir un moyen reproductible de générer du trafic vers l'application.

Ce trafic doit permettre de tester :

- les réponses `2xx`,
- les réponses `4xx`,
- les réponses `5xx`,
- les dashboards,
- les alertes.

### 6. Dashboard Grafana

Votre dashboard Grafana doit contenir au minimum les visualisations suivantes.

#### Panel A : erreurs 5xx sur les 5 dernières minutes

Afficher le nombre total d'erreurs HTTP de la famille `5xx` produites par l'application sur les 5 dernières minutes.

#### Panel B : erreurs 4xx et 5xx sur les 5 dernières minutes

Afficher les erreurs HTTP des familles `4xx` et `5xx` produites par l'application sur les 5 dernières minutes.

Le résultat peut être global ou séparé par famille de code HTTP, tant qu'il reste lisible.

#### Panel C : graphique en ligne

Afficher l'évolution du trafic HTTP par famille de code de réponse.

On doit pouvoir comparer visuellement les réponses `2xx`, `4xx` et `5xx` dans le temps.

#### Panel D : camembert

Afficher la répartition des réponses HTTP par famille de code sur les 5 dernières minutes.

On doit pouvoir identifier rapidement la proportion de succès et d'erreurs.

#### Panel E : graphique propre à votre application

Ajouter au moins un graphique basé sur une métrique spécifique à votre application.

Ce graphique doit apporter une information utile sur le comportement de votre service.

### 7. Tests d'alertes

Vous devez documenter comment vous avez vérifié vos alertes.

Le rendu doit permettre au correcteur de reproduire :

- le déclenchement de l'alerte sur les erreurs `5xx`,
- le déclenchement d'une alerte liée à l'indisponibilité d'un composant,
- le déclenchement de l'alerte liée à l'indisponibilité d'Alertmanager dans Kubernetes.
- le déclenchement de l'alerte propre à votre application.

## Rendu attendu

Votre rendu doit avoir la structure suivante :

```text
nom-prenom-prometheus-grafana/
  README.md
  app/
  manifests/
  grafana/
    dashboard.json
```

Le `README.md` doit contenir :

- La procédure de déploiement.
- La procédure de construction ou de mise à disposition de l'image de votre application.
- La procédure d'accès aux interfaces.
- La méthode de génération de trafic.
- Les choix d'instrumentation de l'application.
- Les requêtes PromQL principales utilisées dans le dashboard et les alertes.
- Le seuil `X` choisi pour l'alerte `5xx`.
- La méthode utilisée pour tester les alertes.
- Les hypothèses ou limites éventuelles.

Le fichier `grafana/dashboard.json` doit être un export du dashboard Grafana.

## Critères de validation

Votre rendu est valide si :

- Il est reproductible sur un cluster vierge.
- Tous les composants obligatoires sont présents.
- Prometheus collecte les métriques attendues.
- Grafana affiche des données après génération de trafic.
- Les alertes sont visibles dans Prometheus.
- Alertmanager reçoit au moins une alerte lorsque cela est possible.
- Le rendu est lisible, documenté et maintenable.