# 🏁 Getting Started - Infrastructure IaC

## Vue d'ensemble

Guide de démarrage rapide pour déployer et utiliser l'infrastructure HomeLab en mode Infrastructure as Code.

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir :

### Environnement de Développement

- Windows avec Visual Studio Enterprise 2022
- Git client configuré
- Docker Desktop (recommandé)
- Accès GitLab.com avec droits appropriés

### Infrastructure Cible

- Serveur Ubuntu 24.04 LTS
- Minimum : 4 CPU, 8 Go RAM, 500 Go SSD
- Réseau privé configuré
- SSH configuré avec clés

### Comptes et Accès

- Compte GitLab.com (gratuit suffisant)
- Variables GitLab CI/CD configurées
- Repository cloné localement

📖 **Guide détaillé** : [prerequisites.md](prerequisites.md)

## ⚡ Quick Start (15 minutes)

### 1. Clone et Configuration

```bash
git clone https://gitlab.com/dev1338/iac.git
cd iac
cp .env.example .env  # À créer selon le template
```

### 2. Configuration Variables

Configurer dans GitLab > Settings > CI/CD > Variables :

- `SSH_PRIVATE_KEY`
- `TF_VAR_server_ip`
- `GITLAB_TOKEN`
- `GITHUB_TOKEN`

### 3. Premier Déploiement

```bash
# Push vers main pour déclencher le pipeline
git checkout main
git push origin main

# Suivre dans GitLab CI/CD > Pipelines
# Approuver manuellement les étapes apply_dev
```

📖 **Guide détaillé** : [quick-start.md](quick-start.md)

## 🎯 Déploiement par Étapes

### Étape 1 : Validation (Automatique)

- Validation syntaxique Terraform/Ansible
- Tests de cohérence
- Vérification versions

### Étape 2 : Planification (Automatique)

- Génération plans Terraform
- Validation changements
- Rapports d'impact

### Étape 3 : Application (Manuel)

- Déploiement infrastructure Terraform
- Configuration services Ansible
- Setup namespaces Kubernetes

### Étape 4 : Monitoring (Automatique)

- Déploiement Prometheus
- Configuration alertes
- Validation métriques

📖 **Guide détaillé** : [first-deployment.md](first-deployment.md)

## 🚦 Niveaux de Déploiement

### 🟢 Niveau 1 : Basic

**Objectif** : Infrastructure fonctionnelle minimale

- Serveur configuré
- K3s déployé
- Monitoring basique

**Durée** : ~30 minutes
**Prérequis** : Serveur Ubuntu + GitLab configuré

### 🟡 Niveau 2 : Standard

**Objectif** : Infrastructure complète avec sécurité

- Tous les namespaces
- Network Policies
- RBAC configuré
- Prometheus déployé

**Durée** : ~1 heure
**Prérequis** : Niveau 1 + variables de sécurité

### 🔴 Niveau 3 : Production

**Objectif** : Infrastructure haute disponibilité

- Monitoring avancé
- Sauvegardes automatiques
- Alerting configuré
- Documentation complète

**Durée** : ~2 heures
**Prérequis** : Niveau 2 + configuration monitoring

## 🎭 Parcours par Rôle

### 👨‍💻 Développeur

1. **Focus** : Compréhension générale, contribution code
2. **Parcours** :
   - [Quick Start](quick-start.md) (lecture)
   - [Architecture Overview](../architecture/overview.md)
   - [Standards de Code](../contributing/coding-standards.md)

### 🛠️ DevOps Engineer

1. **Focus** : Déploiement, configuration, monitoring
2. **Parcours** :
   - [Prerequisites](prerequisites.md) (validation)
   - [First Deployment](first-deployment.md) (exécution)
   - [Guides Techniques](../guides/) (approfondissement)

### 🔧 System Administrator

1. **Focus** : Infrastructure, maintenance, sécurité
2. **Parcours** :
   - [Prerequisites](prerequisites.md) (installation)
   - [Architecture](../architecture/) (compréhension)
   - [Operations](../operations/) (gestion quotidienne)

## ❓ Questions Fréquentes

### Q: Combien de temps pour le premier déploiement ?

**R**: 15-30 minutes pour l'infrastructure de base, 1-2h pour la configuration complète.

### Q: Puis-je tester en local ?

**R**: Oui, utilisez le mode `DRY_RUN=true` pour les validations sans impact.

### Q: Comment suivre les logs en temps réel ?

**R**: GitLab CI/CD > Pipelines > [Pipeline ID] > Jobs > Logs en temps réel.

### Q: Que faire en cas d'erreur ?

**R**: Consultez [Troubleshooting](../troubleshooting/README.md) pour les solutions communes.

## 📞 Support

**Problème de démarrage ?**

1. Vérifiez [Common Issues](../troubleshooting/common-issues.md)
2. Consultez les [Prerequisites](prerequisites.md)
3. Créez une [Issue GitLab](https://gitlab.com/dev1338/iac/-/issues) avec :
   - Description du problème
   - Logs d'erreur
   - Configuration actuelle

---

**Prêt à commencer ?** 👉 [Quick Start Guide](quick-start.md)
