# 🏗️ Infrastructure as Code (IaC) via GitLab CI/CD

[![Pipeline Status](https://img.shields.io/badge/pipeline-GitLab%20CI%2FCD-orange)](https://gitlab.com/dev1338/iac/-/pipelines)
[![IaC](https://img.shields.io/badge/IaC-Terraform%20%7C%20Ansible%20%7C%20Kubernetes-blue)](#)
[![Documentation](https://img.shields.io/badge/docs-complete-brightgreen)](docs/README.md)

## 🎯 Vue d'ensemble

Infrastructure **HomeLab** complètement automatisée utilisant les principes **Infrastructure as Code** (IaC) avec GitLab CI/CD, Terraform, Ansible et Kubernetes.

### Objectifs

- ✅ **Reproductibilité** : Infrastructure versionnable et déployable
- ✅ **Automatisation** : Déploiements via pipelines CI/CD  
- ✅ **Scalabilité** : Architecture modulaire et extensible
- ✅ **Monitoring** : Observabilité complète avec Prometheus

## 🚀 Quick Start

### Prérequis Rapides

- Ubuntu Server 24.04 LTS
- GitLab.com account + Runner configuré
- Variables CI/CD configurées (`SSH_PRIVATE_KEY`, `TF_VAR_server_ip`)

### Déploiement en 15 minutes

```bash
git clone https://gitlab.com/dev1338/iac.git
cd iac
git push origin main  # Déclenche le pipeline
# Approuver manuellement apply_dev dans GitLab UI
```

📖 **Guide complet** : [docs/getting-started/quick-start.md](docs/getting-started/quick-start.md)

## 🏗️ Architecture

```text
┌─────────────────┐     ┌───────────────┐    ┌─────────────────┐
│  Developer      │───▶│  GitLab CI/CD │───▶│  Ubuntu Server  │
│  (VS 2022)      │     │  Pipeline     │    │  (K3s + Apps)   │
└─────────────────┘     └───────────────┘    └─────────────────┘
```

### Stack Technologique

- **IaC** : Terraform (infrastructure) + Ansible (configuration)
- **Orchestration** : Kubernetes (K3s) + Helm
- **CI/CD** : GitLab Pipelines + Self-hosted Runner
- **Monitoring** : Prometheus + métriques automatiques

📖 **Architecture détaillée** : [docs/architecture/README.md](docs/architecture/README.md)

## 📚 Documentation

| Guide | Description | Audience |
|-------|-------------|----------|
| [🏁 Getting Started](docs/getting-started/README.md) | Déploiement rapide | Tous |
| [🏗️ Architecture](docs/architecture/README.md) | Vue d'ensemble technique | DevOps |
| [📖 Guides](docs/guides/README.md) | Documentation par composant | Technique |
| [⚙️ Operations](docs/operations/README.md) | Maintenance et monitoring | Ops |
| [🔧 Troubleshooting](docs/troubleshooting/README.md) | Résolution problèmes | Support |

📖 **Documentation complète** : [docs/README.md](docs/README.md)

## 🛠️ Composants

### Infrastructure (Terraform)

- **Modules** : Variables centralisées, configurations par environnement
- **Environments** : Dev (192.168.1.63) + Prod (192.168.1.64)
- **State** : Management local avec sauvegardes

### Configuration (Ansible)

- **Inventaires** : Générés dynamiquement par Terraform
- **Playbooks** : Configuration services et applications
- **Rôles** : Composants réutilisables

### Orchestration (Kubernetes)

- **Cluster** : K3s single-node avec extensions
- **Namespaces** : `automation`, `databases`, `cache`, `monitoring`
- **Storage** : Classes multiples (SSD, standard, backup)
- **Security** : RBAC + Network Policies

### Monitoring (Prometheus)

- **Métriques** : Infrastructure + Kubernetes + Applications
- **Alerting** : Règles prédéfinies + notifications
- **Storage** : Rétention adaptée par environnement

## 🔄 Workflow CI/CD

```yaml
Stages:
  validate:    # Validation syntaxique (auto)
  plan:        # Planification Terraform (auto)
  apply:       # Déploiement infrastructure (manuel)
  kubernetes:  # Setup K8s + Prometheus (auto)
  deploy:      # Applications Ansible (manuel)
  sync:        # Synchronisation GitHub (auto)
  cleanup:     # Nettoyage ressources (manuel)
```

📖 **Pipeline détaillé** : [docs/guides/gitlab-ci/README.md](docs/guides/gitlab-ci/README.md)

## 📊 État du Projet

### ✅ Fonctionnalités Opérationnelles

- Infrastructure Terraform (dev/prod)
- Pipeline GitLab CI/CD complet
- Cluster Kubernetes K3s
- Namespaces avec quotas et sécurité
- Monitoring Prometheus de base
- Scripts automatisés (installation, validation, déploiement)

### 🔄 En Cours

- Documentation complète (cette tâche)
- Charts Helm personnalisés
- Playbooks Ansible avancés

### 📋 Roadmap

- Grafana + dashboards
- AlertManager + notifications
- Applications de démonstration
- Tests automatisés d'intégration

## 🤝 Contribution

### Workflow de Contribution

1. **Fork** le projet ou créer une branche feature
2. **Développer** avec les standards du projet
3. **Tester** via pipeline CI/CD
4. **Merge Request** vers main avec review

### Standards

- **Code** : HCL formaté, YAML valide, scripts bash lintés
- **Documentation** : Mise à jour systématique
- **Tests** : Validation pipeline obligatoire
- **Sécurité** : Pas de secrets en dur

📖 **Guide détaillé** : [docs/contributing/README.md](docs/contributing/README.md)

## 📞 Support

### Ressources

- **📖 Documentation** : [docs/](docs/README.md)
- **🐛 Issues** : [GitLab Issues](https://gitlab.com/dev1338/iac/-/issues)
- **💬 Discussions** : [GitLab Discussions](https://gitlab.com/dev1338/iac/-/discussions)
- **📊 Monitoring** : Prometheus (port-forward depuis K3s)

### Contact

- **Équipe Infrastructure** : Via GitLab Issues
- **Urgences** : SSH direct vers serveurs + logs
- **Améliorations** : Merge Requests bienvenues

---

## 📋 TL;DR

```bash
# Clone + Configuration
git clone https://gitlab.com/dev1338/iac.git && cd iac

# Déploiement automatique
git push origin main
# → Suivre pipeline GitLab
# → Approuver apply_dev manuellement
# → Infrastructure prête en 15 min

# Accès services
ssh ubuntu@192.168.1.63
sudo k3s kubectl get all -A
sudo k3s kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

**🎯 Next**: [Documentation Complète](docs/README.md) | [Quick Start](docs/getting-started/quick-start.md)

---

*Dernière mise à jour : {{ current_date }} | Version : v3.2.0*
