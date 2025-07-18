# 📋 Prérequis - Configuration Environnement

## Vue d'ensemble

Ce guide détaille tous les prérequis nécessaires pour déployer et maintenir l'infrastructure HomeLab IaC.

## 🖥️ Environnement de Développement

### Windows + Visual Studio

```powershell
# Vérification version Windows
winver
# Requis : Windows 10/11 Pro ou Enterprise

# Visual Studio Enterprise 2022
# Avec workloads :
# - ASP.NET and web development
# - Azure development (optionnel)
```

### Git Configuration

```bash
# Installation Git for Windows
winget install Git.Git

# Configuration globale
git config --global user.name "Votre Nom"
git config --global user.email "votre.email@domain.com"
git config --global init.defaultBranch main

# Vérification
git --version  # >= 2.40.0 recommandé
```

### Docker Desktop

```powershell
# Installation via winget
winget install Docker.DockerDesktop

# Configuration post-installation
# - Enable WSL 2 backend
# - Configure resource limits (8GB RAM minimum)
# - Enable Kubernetes (optionnel pour dev local)

# Vérification
docker --version  # >= 24.0.0
docker-compose --version  # >= 2.20.0
```

## 🖥️ Infrastructure Serveur

### Ubuntu Server 24.04 LTS

```bash
# Vérification version
lsb_release -a
# Requis : Ubuntu 24.04 LTS

# Mise à jour système
sudo apt update && sudo apt upgrade -y

# Installation packages essentiels
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg \
    lsb-release \
    git \
    wget \
    unzip
```

### Configuration Réseau

```bash
# Configuration IP statique
sudo nano /etc/netplan/00-network-config.yaml
```

**Contenu `/etc/netplan/00-network-config.yaml`** :

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:  # Adapter selon votre interface
      dhcp4: no
      addresses:
        - 192.168.1.63/24  # Dev server
        # ou
        - 192.168.1.64/24  # Prod server
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 192.168.1.1
          - 8.8.8.8
```

```bash
# Application configuration
sudo netplan apply

# Vérification
ip addr show
ping 8.8.8.8
```

### Configuration SSH

```bash
# Génération clé SSH (si nécessaire)
ssh-keygen -t ed25519 -C "homelab-infrastructure"

# Configuration SSH server
sudo nano /etc/ssh/sshd_config
```

**Configuration SSH recommandée** :

```bash
Port 22
PermitRootLogin no
PasswordAuthentication yes  # Temporaire, désactiver après setup clés
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ClientAliveInterval 60
ClientAliveCountMax 3
```

```bash
# Redémarrage SSH
sudo systemctl restart sshd
sudo systemctl enable sshd

# Test connexion
ssh ubuntu@192.168.1.63  # ou 64 pour prod
```

### Installation Docker

```bash
# Ajout repository Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installation
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Configuration permissions
sudo usermod -aG docker $USER
sudo usermod -aG docker gitlab-runner  # Pour plus tard

# Test
docker --version
docker run hello-world
```

### Installation GitLab Runner

```bash
# Ajout repository GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash

# Installation
sudo apt install gitlab-runner

# Vérification
gitlab-runner --version
```

## 🔑 Configuration GitLab

### Compte GitLab.com

1. **Création compte** : [gitlab.com/users/sign_up](https://gitlab.com/users/sign_up)
2. **Fork projet** : [gitlab.com/dev1338/iac](https://gitlab.com/dev1338/iac)
3. **Clé SSH** : Ajouter votre clé publique dans Profile > SSH Keys

### Configuration Variables CI/CD

Dans GitLab : **Settings > CI/CD > Variables**

#### Variables Obligatoires

```bash
# SSH_PRIVATE_KEY (Type: File, Protected: ✓, Masked: ✗)
# Contenu de votre clé privée SSH
-----BEGIN OPENSSH PRIVATE KEY-----
[votre clé privée]
-----END OPENSSH PRIVATE KEY-----

# TF_VAR_server_ip (Type: Variable, Protected: ✓, Masked: ✗)
192.168.1.63  # pour dev
# ou
192.168.1.64  # pour prod

# GITLAB_TOKEN (Type: Variable, Protected: ✓, Masked: ✓)
# Token avec scope: api, read_api, read_repository
glpat-xxxxxxxxxxxxxxxxxxxx

# GITHUB_TOKEN (Type: Variable, Protected: ✓, Masked: ✓)
# Token GitHub pour synchronisation (optionnel)
ghp_xxxxxxxxxxxxxxxxxxxx
```

#### Variables Optionnelles

```bash
# ANSIBLE_HOST_KEY_CHECKING (Type: Variable, Protected: ✗, Masked: ✗)
False

# TF_VAR_domain_name (Type: Variable, Protected: ✗, Masked: ✗)
homelab.local

# DEBUG (Type: Variable, Protected: ✗, Masked: ✗)
false
```

### Enregistrement GitLab Runner

```bash
# Sur le serveur Ubuntu
sudo gitlab-runner register

# Paramètres à fournir :
# GitLab instance URL: https://gitlab.com/
# Registration token: [depuis GitLab Settings > CI/CD > Runners]
# Description: homelab-runner-dev (ou prod)
# Tags: terraform,ansible,kubernetes
# Executor: docker
# Default image: alpine:latest
```

**Validation registration** :

```bash
# Vérification runner
sudo gitlab-runner list
sudo gitlab-runner status

# Test dans GitLab
# Settings > CI/CD > Runners > Vérifier runner en ligne
```

## 🔧 Outils Locaux (Optionnels)

### Terraform CLI

```bash
# Windows (PowerShell)
$version = "1.12.1"
Invoke-WebRequest -Uri "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_windows_amd64.zip" -OutFile "terraform.zip"
Expand-Archive terraform.zip -DestinationPath "C:\terraform"
$env:PATH += ";C:\terraform"

# Vérification
terraform --version
```

### Ansible (WSL ou VM Linux)

```bash
# WSL Ubuntu
sudo apt update
sudo apt install -y ansible

# Vérification
ansible --version
```

### kubectl

```bash
# Windows (PowerShell)
$version = "v1.33.1"
Invoke-WebRequest -Uri "https://dl.k8s.io/release/${version}/bin/windows/amd64/kubectl.exe" -OutFile "kubectl.exe"
Move-Item kubectl.exe "C:\tools\kubectl.exe"
$env:PATH += ";C:\tools"

# Vérification
kubectl version --client
```

## ✅ Liste de Vérification

### ✅ Environnement de Développement

- [ ] Windows 10/11 Pro/Enterprise
- [ ] Visual Studio Enterprise 2022 installé
- [ ] Git configuré avec credentials
- [ ] Docker Desktop fonctionnel
- [ ] Repository IaC cloné

### ✅ Infrastructure Serveur

- [ ] Ubuntu 24.04 LTS installé
- [ ] IP statique configurée
- [ ] SSH fonctionnel avec clés
- [ ] Docker installé et testé
- [ ] GitLab Runner installé

### ✅ Configuration GitLab

- [ ] Compte GitLab.com créé
- [ ] Projet forké/accessible
- [ ] Variables CI/CD configurées
- [ ] Runner enregistré et actif
- [ ] SSH Keys ajoutées au profil

### ✅ Connectivité

- [ ] SSH depuis dev vers serveur
- [ ] Ping depuis serveur vers internet
- [ ] GitLab Runner peut pull images Docker
- [ ] DNS résolution fonctionnelle

## 🔧 Validation Environnement

### Script de Validation Automatique

```bash
#!/bin/bash
# validate-environment.sh

echo "🔍 Validation environnement HomeLab IaC..."

# Vérification Ubuntu
if [[ $(lsb_release -rs) == "24.04" ]]; then
    echo "✅ Ubuntu 24.04 LTS"
else
    echo "❌ Ubuntu version non supportée"
fi

# Vérification Docker
if docker --version >/dev/null 2>&1; then
    echo "✅ Docker installé: $(docker --version)"
else
    echo "❌ Docker non installé"
fi

# Vérification GitLab Runner
if gitlab-runner --version >/dev/null 2>&1; then
    echo "✅ GitLab Runner: $(gitlab-runner --version)"
else
    echo "❌ GitLab Runner non installé"
fi

# Vérification connectivité
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Connectivité internet"
else
    echo "❌ Pas de connectivité internet"
fi

# Vérification SSH
if systemctl is-active --quiet sshd; then
    echo "✅ Service SSH actif"
else
    echo "❌ Service SSH inactif"
fi

echo "🎯 Validation terminée"
```

## 🚨 Troubleshooting Commun

### Problème : GitLab Runner offline

```bash
# Vérification statut
sudo gitlab-runner status

# Redémarrage si nécessaire
sudo gitlab-runner restart

# Logs
sudo journalctl -u gitlab-runner -f
```

### Problème : Docker permission denied

```bash
# Ajout utilisateur au groupe docker
sudo usermod -aG docker $USER
sudo usermod -aG docker gitlab-runner

# Redémarrage session ou serveur
sudo reboot
```

### Problème : SSH connection refused

```bash
# Vérification service SSH
sudo systemctl status sshd

# Vérification port
sudo netstat -tlnp | grep :22

# Logs SSH
sudo journalctl -u ssh -f
```

## 📞 Support

**Problème de prérequis ?**

1. Vérifiez chaque étape individuellement
2. Consultez les logs système (`journalctl -f`)
3. Testez la connectivité réseau
4. Créez une [Issue GitLab](https://gitlab.com/dev1338/iac/-/issues)

---

**Prérequis validés ?** 👉 [Quick Start Guide](quick-start.md)
