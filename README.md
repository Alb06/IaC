# Infrastructure as Code (IaC) via GitLab CI/CD

## Vue d'ensemble

Ce projet implémente une approche Infrastructure as Code (IaC) complète via GitLab CI/CD pour automatiser le déploiement, la configuration et la gestion d'infrastructure sur un serveur Ubuntu 24.04.

L'objectif est de créer une infrastructure reproductible, versionnable et maintenable en utilisant des outils modernes de provisionnement et d'orchestration.

![Badges](https://img.shields.io/badge/IaC-Terraform%20%7C%20Ansible%20%7C%20Kubernetes-blue)
![Pipeline Status](https://img.shields.io/badge/pipeline-GitLab%20CI%2FCD-orange)

## Architecture et composants

```
┌─────────────────┐         ┌───────────────┐        ┌─────────────────┐
│  Windows Dev    │         │  GitLab.com   │        │  Ubuntu Server  │
│  VS 2022        │ ───►    │ CI/CD Pipeline│ ───►   │  24.04 LTS      │
└─────────────────┘         └───────────────┘        └─────────────────┘
   Développement                Pipelines              Infrastructure
```

### Composants principaux

- **Terraform** (v1.11.4) : Provisionnement de l'infrastructure
- **Ansible** : Configuration et déploiement d'applications
- **Kubernetes/Helm** : Orchestration de conteneurs
- **GitLab CI/CD** : Automatisation des workflows de déploiement
- **Docker** : Conteneurisation des services

## Prérequis

### Machine de développement

- Windows avec Visual Studio Enterprise 2022
- Git client
- Docker Desktop (recommandé)
- Terraform CLI (optionnel, déjà inclus dans le pipeline)

### Serveur cible

- Ubuntu Server 24.04 LTS
- Sur le même réseau privé que la machine de développement
- Minimum recommandé : 4 CPU, 8 Go RAM, 500 Go SSD
- Configuration réseau : IP fixe

### GitLab

- Compte GitLab.com (licence gratuite)
- GitLab Runner installé et configuré sur le serveur

## Structure du projet

```
/
├── .gitlab-ci.yml                 # Configuration pipeline CI/CD
├── README.md                      # Ce fichier
├── terraform/                     # Configuration Infrastructure
│   ├── modules/                   # Modules Terraform réutilisables
│   ├── environments/              # Configurations spécifiques aux environnements
│   │   ├── dev/                   # Environnement de développement
│   │   └── prod/                  # Environnement de production
│   └── variables/                 # Définitions des variables
├── ansible/                       # Configuration et déploiement
│   ├── playbooks/                 # Playbooks Ansible
│   ├── roles/                     # Rôles réutilisables
│   └── inventory/                 # Inventaires des environnements
├── kubernetes/                    # Orchestration des conteneurs
│   ├── manifests/                 # Manifestes Kubernetes
│   └── helm-charts/               # Charts Helm personnalisés
└── scripts/                       # Scripts utilitaires
    └── ci-cd/                     # Scripts spécifiques au CI/CD
```

## Installation et configuration

### 1. Clonage du projet

```bash
git clone https://gitlab.com/dev1338/iac.git
cd iac
```

### 2. Configuration du serveur

Le serveur Ubuntu doit être préparé avec les éléments suivants :

```bash
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Installation des dépendances
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release git

# Installation de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER

# Installation du GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install gitlab-runner
sudo usermod -aG docker gitlab-runner
```

### 3. Enregistrement du GitLab Runner

```bash
sudo gitlab-runner register
# Suivez les instructions à l'écran :
# - URL GitLab : https://gitlab.com/
# - Token : [disponible dans les paramètres CI/CD de votre projet]
# - Description : [nom descriptif pour votre runner]
# - Tags : terraform,ansible,kubernetes
# - Executor : docker
# - Image par défaut : alpine:latest
```

## Workflow CI/CD

Notre pipeline est structuré en plusieurs étapes:

1. **Validate** : Vérifie la syntaxe et la cohérence des fichiers Terraform
2. **Plan** : Génère et affiche un plan des modifications à appliquer
3. **Apply** : Applique les modifications (validation manuelle requise)
4. **Cleanup** : Nettoie les ressources temporaires (optionnel)

![Pipeline Workflow](https://mermaid.ink/img/pako:eNp1kM1qwzAQhF9F7CkFv0DooT9QeughpQdTL0FaK4uw5KDVQnDw2_eiOnZDSnejZWfmW7hJbTAK16mP0RnCDxRcG0cU7UMP7EgkRawecIMNYYeOYXKOQxS6oLDY4Fy2TJ3W8kkbbBCahH9uozEZ3w9U5Ys-bnOBvdH0H1XefKqNzaRbUyrhvbchTFYwyJuEySs0FjW3-pHXbV03sqqXy16oulHNqlJN_dxW7apqygpRJHLo4OkP6Sj-ePfK1GsQ3h7HgIk-2R6cPRSPsvwFkslr0Q)

## Variables d'environnement

Les variables suivantes doivent être configurées dans les paramètres CI/CD du projet GitLab:

| Variable | Description | Exemple |
|----------|-------------|---------|
| `TF_VAR_server_ip` | Adresse IP du serveur cible | `192.168.1.100` |
| `TF_VAR_domain_name` | Nom de domaine (si applicable) | `example.com` |
| `ANSIBLE_HOST_KEY_CHECKING` | Désactive la vérification des clés SSH | `False` |
| `SSH_PRIVATE_KEY` | Clé SSH pour la connexion au serveur | `-----BEGIN RSA PRIVATE KEY...` |

## Commandes utiles

### Terraform (local)

```bash
# Initialisation
terraform init

# Vérification de la syntaxe
terraform validate

# Création du plan
terraform plan -out=tfplan

# Application du plan
terraform apply tfplan
```

### GitLab CI/CD

```bash
# Exécution manuelle du pipeline
gitlab-runner exec docker validate --env TF_ROOT=${PWD}/terraform/environments

# Vérification du statut du runner
sudo gitlab-runner status
```

## Troubleshooting

### Problèmes courants

1. **Erreur "sh: not found"** : Les images Docker minimalistes (Alpine) nécessitent l'installation de bash via `apk add --no-cache bash`.

2. **Problèmes d'accès SSH** : Vérifiez que la clé privée est correctement configurée dans les variables CI/CD et que l'utilisateur cible dispose des autorisations nécessaires.

3. **Terraform "Plugin reinitialization required"** : Supprimez le répertoire `.terraform` et relancez `terraform init`.

## Standards et bonnes pratiques

- **Code Terraform** : Modulaire, réutilisable et documenté
- **Conventions de nommage** : snake_case pour les variables, ressources et fichiers
- **Variables d'environnement** : Utilisées pour les valeurs spécifiques à l'environnement
- **Secrets** : Jamais stockés en clair, toujours dans les variables GitLab CI/CD
- **Documentation** : README par module/composant expliquant son utilisation

## État actuel du projet

- ✅ Configuration du serveur Ubuntu 24.04
- ✅ Installation des prérequis (Docker, GitLab Runner)
- ✅ Configuration du pipeline CI/CD
- ✅ Structure de base du projet
- ⏳ Modules Terraform initiaux
- ⏳ Playbooks Ansible
- ⏳ Configuration Kubernetes/Helm

## Contributions

Pour contribuer à ce projet :

1. Créez une nouvelle branche à partir de `main`
2. Effectuez vos modifications
3. Soumettez une Merge Request vers `main`
4. Attendez la validation du pipeline CI/CD
5. Demandez une revue de code

## Licence

Ce projet est sous licence interne et ne doit pas être distribué sans autorisation.

---

*Dernière mise à jour : avril 2025*