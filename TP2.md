# TP ELK Stack

## Contexte

Vous avez déjà travaillé sur Prometheus et Grafana pour mesurer une application. Ce TP se concentre maintenant sur les logs.

Votre objectif est de déployer une stack ELK dans Kubernetes, d'y ingérer les logs d'une application HTTP, puis de créer des recherches et dashboards Kibana adaptés à deux usages :

- investigation développeur ;
- lecture support ou métier.

Une partie du TP utilise aussi un dataset fourni, `Air_Quality.log`, afin de valider vos compétences Kibana sur un jeu de données stable.

Le rendu doit démontrer que vous comprenez la chaîne complète : production de logs, collecte, transformation, indexation, recherche et visualisation.

## Contraintes

- Le cluster local doit être créé avec `kind`.
- Le rendu doit utiliser des manifests Kubernetes simples.
- Le rendu ne doit pas être un export brut généré par Helm.
- Les composants Elastic doivent être déployés dans Kubernetes.
- Les logs applicatifs doivent être collectés depuis Kubernetes.
- Le dataset Air Quality doit être importé dans Elasticsearch via Logstash CSV.
- Kibana doit permettre de rechercher et visualiser les logs ingérés.
- Vous devez fournir vos fichiers sources, pas seulement des captures d'écran.

## Composants obligatoires

Votre cluster doit contenir au minimum :

- Elasticsearch.
- Kibana.
- Logstash.
- Filebeat.
- Une application HTTP qui écrit des logs structurés.

Les manifests doivent utiliser les images suivantes pour la stack Elastic :

| Composant          | Image Docker obligatoire                                                         |
| ------------------ | -------------------------------------------------------------------------------- |
| Elasticsearch      | `docker.elastic.co/elasticsearch/elasticsearch:8.19.16`                          |
| Kibana             | `docker.elastic.co/kibana/kibana:8.19.16`                                        |
| Logstash           | `docker.elastic.co/logstash/logstash:8.19.16`                                    |
| Filebeat           | `docker.elastic.co/beats/filebeat:8.19.16`                                       |
| Application HTTP   | image produite par vous, avec tag figé et documenté                              |
| Import Air Quality | image produite par vous, basée sur `docker.elastic.co/logstash/logstash:8.19.16` |

Vous êtes responsables du choix et de l'organisation des ressources Kubernetes nécessaires pour faire fonctionner ces composants.

## Application attendue

Vous devez développer une petite application HTTP dans le langage de votre choix.

L'application doit produire des logs structurés exploitables dans Kibana. Elle doit permettre de générer plusieurs scénarios observables :

- trafic nominal ;
- erreurs client ;
- erreurs serveur ;
- au moins un comportement métier ou technique propre à votre application.

Les logs doivent contenir assez d'informations pour permettre une recherche utile dans Kibana. Les données sensibles sont interdites dans les logs.

Le correcteur doit pouvoir envoyer des requêtes HTTP ou HTTPS vers votre application, selon l'accès que vous documentez, puis observer les logs produits dans Kibana.

## Travail demandé

### 1. Stack ELK

Déployez l'ensemble des composants obligatoires dans Kubernetes.

Votre rendu doit pouvoir être rejoué sur un cluster vierge par le correcteur.

### 2. Ingestion des logs

Les logs de l'application doivent être collectés depuis Kubernetes, passer par la chaîne d'ingestion, puis être disponibles dans Elasticsearch.

Votre configuration doit permettre de distinguer les logs de votre application des logs techniques de la stack.

### 3. Recherche Kibana

Kibana doit permettre de rechercher les logs de votre application.

Le correcteur doit pouvoir vérifier :

- qu'une recherche temporelle fonctionne ;
- qu'une recherche par niveau de log fonctionne ;
- qu'une recherche par route ou action fonctionne ;
- qu'une recherche par identifiant de requête ou équivalent fonctionne ;
- qu'une recherche sur les erreurs fonctionne.

### 4. Dashboard développeur

Créez un dashboard destiné à un développeur qui investigue un incident.

Ce dashboard doit aider à répondre à des questions techniques :

- où sont les erreurs ;
- quand ont-elles commencé ;
- quelles routes ou actions sont concernées ;
- quels messages reviennent le plus souvent ;
- quels événements récents méritent d'être lus.

### 5. Dashboard support

Créez un dashboard destiné à une personne support ou moins technique.

Ce dashboard doit être lisible sans connaître l'implémentation de l'application. Il doit permettre de suivre l'état fonctionnel du service sans modifier l'ingestion des logs.

### 6. Mini-TP Air Quality

Le fichier `datasets/Air_Quality.log` est fourni avec le sujet. Vous devez l'importer dans Elasticsearch via Logstash CSV, dans un index dédié de type :

```text
air-quality-*
```

L'import ne doit pas être fait uniquement avec l'outil d'upload Kibana. Il doit être reproductible depuis vos sources.

Dans Kibana, créez une Data View `air-quality-*` avec `@timestamp` comme champ temporel.

Travail demandé sur ce dataset :

- retrouver des pics de pollution sur une période entre 2008 et 2014 ;
- faire au moins une recherche combinant un polluant, `data_value > 10` et une fenêtre temporelle ;
- afficher uniquement les champs utiles dans Discover et trier les résultats par `data_value` décroissant ;
- créer une visualisation Lens time-series avec `Average(data_value)` sur `@timestamp`, découpée par polluant ;
- créer une visualisation de comparaison par période et par polluant, par exemple heatmap ou table ;
- créer un dashboard interactif contenant vos visualisations Air Quality ;
- ajouter un contrôle de type Options list sur le lieu géographique et vérifier le filtre sur `Bronx`.

Des captures d'écran suffiront pour montrer que les requêtes/dashboards ont été faites. Déposez les dans votre répo/zip

### 7. Scénarios de validation

Vous devez fournir un moyen reproductible de générer des logs.

Ces scénarios doivent permettre de tester :

- les logs nominaux ;
- les logs d'erreur client ;
- les logs d'erreur serveur ;
- le dashboard développeur ;
- le dashboard support ;
- au moins une recherche par identifiant de requête ou équivalent.
- l'import et les visualisations Air Quality.

## Rendu attendu

Votre rendu doit avoir la structure suivante :

```text
nom-prenom-elk/
  README.md
  app/
  air-quality-importer/
  datasets/
  manifests/
  kibana/
```

Le `README.md` doit contenir :

- la procédure de déploiement ;
- la procédure de construction ou de mise à disposition de l'image de votre application ;
- la procédure d'accès à Kibana et à l'application ;
- la méthode de génération des logs ;
- la méthode d'import du dataset Air Quality ;
- les choix de structuration des logs ;
- les recherches Kibana principales ;
- la description des dashboards ;
- les hypothèses ou limites éventuelles.

Le dossier `kibana/` doit contenir les exports nécessaires pour réimporter vos dashboards ou objets Kibana.

## Critères de validation

Votre rendu est valide si :

- il est reproductible sur un cluster vierge ;
- tous les composants obligatoires sont présents ;
- les logs de l'application sont visibles dans Kibana ;
- les données Air Quality sont visibles dans Kibana ;
- les recherches demandées sont possibles ;
- les dashboards affichent des données après génération de trafic ;
- le dashboard Air Quality contient un contrôle interactif fonctionnel ;
- le dashboard développeur aide réellement à investiguer ;
- le dashboard support est lisible et adapté à un profil non technique ;
- le rendu est documenté et maintenable.