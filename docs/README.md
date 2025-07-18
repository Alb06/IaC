# 📚 Documentation Infrastructure as Code (IaC)

## Vue d'ensemble

Cette documentation présente l'infrastructure HomeLab automatisée via GitLab CI/CD, utilisant Terraform, Ansible et Kubernetes pour une approche Infrastructure as Code complète.

## 🚀 Navigation Rapide

### 🏁 Démarrage

- [**Quick Start**](getting-started/quick-start.md) - Déploiement en 15 minutes
- [**Prérequis**](getting-started/prerequisites.md) - Configuration environnement
- [**Premier Déploiement**](getting-started/first-deployment.md) - Guide étape par étape

### 🏗️ Architecture

- [**Vue d'ensemble**](architecture/overview.md) - Schéma global infrastructure
- [**Environnements**](architecture/environments.md) - Configuration dev/prod
- [**Sécurité**](architecture/security-model.md) - Modèle de sécurité

### 📖 Guides Techniques

- [**Terraform**](guides/terraform/README.md) - Modules et configurations
- [**Ansible**](guides/ansible/README.md) - Playbooks et inventaires
- [**Kubernetes**](guides/kubernetes/README.md) - Manifests et Helm charts
- [**GitLab CI/CD**](guides/gitlab-ci/README.md) - Pipelines et scripts
- [**Monitoring**](guides/monitoring/README.md) - Prometheus et observabilité

### ⚙️ Opérations

- [**Déploiement**](operations/deployment.md) - Procédures de déploiement
- [**Maintenance**](operations/maintenance.md) - Tâches de maintenance
- [**Sauvegarde**](operations/backup-recovery.md) - Stratégies de sauvegarde
- [**Monitoring**](operations/monitoring.md) - Surveillance infrastructure

### 🔧 Dépannage

- [**Problèmes Courants**](troubleshooting/common-issues.md) - Solutions rapides
- [**Debug Terraform**](troubleshooting/terraform-debugging.md) - Diagnostic Terraform
- [**Debug Ansible**](troubleshooting/ansible-debugging.md) - Diagnostic Ansible
- [**Échecs Pipeline**](troubleshooting/pipeline-failures.md) - Debug GitLab CI/CD

### 📚 Référence

- [**Variables**](reference/variables.md) - Toutes les variables configurables
- [**Modules**](reference/modules.md) - Documentation modules Terraform
- [**Scripts**](reference/scripts-reference.md) - Référence scripts CI/CD

### 🤝 Contribution

- [**Standards**](contributing/coding-standards.md) - Standards de développement
- [**Tests**](contributing/testing.md) - Guide de tests
- [**Release**](contributing/release-process.md) - Processus de release

## 🏷️ Par Rôle

### 👨‍💻 Développeur

1. [Quick Start](getting-started/quick-start.md)
2. [Architecture Overview](architecture/overview.md)
3. [Standards de Code](contributing/coding-standards.md)

### 🛠️ DevOps Engineer

1. [Architecture Complète](architecture/)
2. [Guides Techniques](guides/)
3. [Opérations](operations/)

### 🔧 System Administrator

1. [Prérequis](getting-started/prerequisites.md)
2. [Déploiement](operations/deployment.md)
3. [Maintenance](operations/maintenance.md)
4. [Troubleshooting](troubleshooting/)

## 📊 Métriques Documentation

| Composant | Couverture | Dernière MAJ | Status |
|-----------|------------|--------------|--------|
| Terraform | 🟢 Complète | 2025-01-XX | ✅ |
| Ansible | 🟡 Partielle | 2025-01-XX | 🔄 |
| Kubernetes | 🔴 Basique | 2025-01-XX | 📝 |
| GitLab CI/CD | 🟢 Complète | 2025-01-XX | ✅ |

## 🔄 Mise à Jour

Cette documentation est générée automatiquement et mise à jour à chaque release.

- **Dernière mise à jour** : {{ current_date }}
- **Version documentation** : v1.0.0
- **Version infrastructure** : v3.2.0

## 📞 Support

- **Issues** : [GitLab Issues](https://gitlab.com/dev1338/iac/-/issues)
- **Discussions** : [GitLab Discussions](https://gitlab.com/dev1338/iac/-/discussions)
- **Wiki** : [GitLab Wiki](https://gitlab.com/dev1338/iac/-/wikis)

---

> 💡 **Tip** : Utilisez la recherche GitLab (`Ctrl+K`) pour trouver rapidement du contenu dans cette documentation.
