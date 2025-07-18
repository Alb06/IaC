# ⚡ Quick Start - Déploiement en 15 minutes

## Vue d'ensemble

Guide de déploiement rapide de l'infrastructure HomeLab IaC. Ce guide vous permet de déployer une infrastructure fonctionnelle en moins de 15 minutes.

> 📋 **Prérequis** : [Prerequisites](prerequisites.md) validés et configuration GitLab terminée.

## 🎯 Objectif

À la fin de ce guide, vous aurez :

- ✅ Infrastructure Terraform déployée (serveur configuré)
- ✅ Cluster K3s opérationnel
- ✅ Namespaces Kubernetes créés
- ✅ Monitoring Prometheus fonctionnel
- ✅ Pipeline GitLab CI/CD actif

## ⏱️ Timeline

| Étape | Durée | Action |
|-------|-------|--------|
| 1-3 | 2 min | Configuration initiale |
| 4-5 | 5 min | Pipeline automatique |
| 6-7 | 5 min | Validation manuelle |
| 8-9 | 3 min | Tests et vérification |

> **Total : ~15 minutes**

## 🚀 Étapes de Déploiement

### 1. Clone du Repository

```bash
# Clone du projet
git clone https://gitlab.com/dev1338/iac.git
cd iac

# Vérification structure
ls -la
# Doit afficher : terraform/, ansible/, kubernetes/, .gitlab-ci.yml
```

### 2. Configuration Environment (Optionnel)

```bash
# Copie template configuration locale (si nécessaire)
cp .env.example .env 2>/dev/null || echo "# Configuration locale" > .env

# Édition variables locales (optionnel)
echo "ENVIRONMENT=dev" >> .env
echo "DEBUG=false" >> .env
```

### 3. Vérification Variables GitLab

**GitLab > Settings > CI/CD > Variables** - Vérifiez :

- ✅ `SSH_PRIVATE_KEY` (votre clé privée)
- ✅ `TF_VAR_server_ip` (IP de votre serveur)
- ✅ `GITLAB_TOKEN` (token d'accès)

### 4. Déclenchement Pipeline

```bash
# Basculer sur main (si pas déjà)
git checkout main

# Push pour déclencher pipeline
git push origin main

# Ou forcer redéclenchement
git commit --allow-empty -m "feat: trigger initial deployment"
git push origin main
```

### 5. Suivi Pipeline (5 minutes)

**GitLab > CI/CD > Pipelines** - Suivez l'exécution :

```text
🔄 STAGE: validate (automatique - 1 min)
├── validate_versions ✅
└── validate ✅

🔄 STAGE: plan (automatique - 2 min)
├── plan_dev ✅
└── plan_prod ✅

🔄 STAGE: apply (manuel - requis)
├── apply_dev ⏸️ [CLIQUER POUR EXÉCUTER]
└── apply_prod ⏸️ [EN ATTENTE]
```

### 6. Approbation Manuelle - Dev

**Dans GitLab Pipeline > `apply_dev`** :

1. Cliquer sur **"Play"** ▶️
2. Attendre fin d'exécution (~2 minutes)
3. Vérifier **"Job succeeded"** ✅

### 7. Validation Infrastructure Kubernetes

**Pipeline continue automatiquement** :

```text
🔄 STAGE: kubernetes (automatique - 2 min)
├── kubernetes_setup_dev ✅
├── deploy_prometheus_dev ✅
└── kubernetes_validate ✅
```

### 8. Tests de Connectivité

```bash
# Test SSH vers serveur
ssh ubuntu@192.168.1.63  # Adapter selon votre IP

# Sur le serveur - vérifications
docker --version
sudo k3s kubectl get nodes
sudo k3s kubectl get namespaces
```

### 9. Validation Prometheus

```bash
# Port-forward pour accès Prometheus (sur serveur)
sudo k3s kubectl port-forward -n monitoring svc/prometheus 9090:9090 &

# Test santé Prometheus (depuis serveur ou tunnel SSH)
curl -s http://localhost:9090/-/healthy
# Réponse attendue : "Prometheus is Healthy."
```

## 📊 Validation Déploiement

### ✅ Checklist Infrastructure

```bash
# Sur le serveur Ubuntu
# 1. Docker opérationnel
docker ps
# Doit montrer containers K3s actifs

# 2. K3s cluster
sudo k3s kubectl get nodes -o wide
# Doit montrer 1 node "Ready"

# 3. Namespaces créés
sudo k3s kubectl get namespaces
# Doit afficher : automation, databases, cache, monitoring

# 4. Prometheus déployé
sudo k3s kubectl get pods -n monitoring
# Doit montrer pod prometheus "Running"

# 5. Storage classes
sudo k3s kubectl get storageclass
# Doit afficher : local-path, local-ssd-fast, local-standard
```

### ✅ Checklist GitLab

- **Pipeline Status** : ✅ Succeeded
- **Runner** : 🟢 Online dans Settings > CI/CD > Runners  
- **Variables** : 🔒 Configurées et protégées
- **Artifacts** : 📦 terraform_outputs.json généré

### ✅ Accès Services

```bash
# Prometheus (via port-forward)
sudo k3s kubectl port-forward -n monitoring svc/prometheus 9090:9090

# K3s Dashboard (optionnel)
sudo k3s kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443
```

## 🎉 Félicitations [Punctuation: '!']

Votre infrastructure HomeLab IaC est opérationnelle !

### 🔗 Prochaines Étapes

1. **Exploration** : [Architecture Overview](../architecture/overview.md)
2. **Déploiement Prod** : Répéter avec `apply_prod`
3. **Monitoring** : Configurer alertes Prometheus
4. **Applications** : Déployer vos premières applications

### 📈 Monitoring

- **Prometheus** : http://VOTRE_IP:9090 (via port-forward)
- **K3s Metrics** : Déjà collectées automatiquement
- **Logs** : `sudo k3s kubectl logs -n monitoring deployment/prometheus`

## 🚨 Problèmes Courants

### ❌ Pipeline Failed au Stage "apply"

```bash
# Vérification SSH
ssh ubuntu@192.168.1.63

# Vérification GitLab Runner
sudo gitlab-runner status

# Logs détaillés
sudo journalctl -u gitlab-runner -f
```

### ❌ Prometheus Pod CrashLoopBackOff

```bash
# Diagnostic pod
sudo k3s kubectl describe pod -n monitoring -l app.kubernetes.io/name=prometheus

# Vérification PVC
sudo k3s kubectl get pvc -n monitoring
# Status doit être "Bound"
```

### ❌ Variables GitLab non reconnues

1. **Vérifier** : GitLab > Settings > CI/CD > Variables
2. **Recreer** : Supprimer et recréer les variables
3. **Relancer** : Pipeline via GitLab

## 🔄 Redéploiement Rapide

```bash
# Nettoyage et redéploiement complet
git commit --allow-empty -m "feat: redeploy infrastructure"
git push origin main

# Puis suivre étapes 5-9
```

## 📞 Support Rapide

**Problème de démarrage ?**

- 📖 [Common Issues](../troubleshooting/common-issues.md)
- 🐛 [GitLab Issues](https://gitlab.com/dev1338/iac/-/issues)
- 💬 Support : Créer issue avec logs d'erreur

---

**Infrastructure déployée ?** 👉 [Architecture Overview](../architecture/overview.md)
