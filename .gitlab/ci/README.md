# 🏗️ Pipeline GitLab CI/CD - Architecture Modulaire

## 📋 Vue d'ensemble

Cette structure modulaire remplace le fichier monolithique `.gitlab-ci.yml` pour améliorer :

- **Maintenabilité** : Code organisé en modules logiques
- **Réutilisabilité** : Templates et jobs partagés
- **Lisibilité** : Séparation claire des responsabilités
- **Évolutivité** : Ajout facile de nouveaux composants

## 🗂️ Structure des Dossiers

### 📁 `.gitlab/ci/`

#### `includes/`

Modules YAML inclus dans le pipeline principal :

- `variables.yml` : Variables globales et configuration cache
- `templates.yml` : Templates de jobs réutilisables
- `terraform.yml` : Jobs spécifiques Terraform
- `ansible.yml` : Jobs de déploiement Ansible
- `sync.yml` : Jobs de synchronisation (GitHub, issues)
- `cleanup.yml` : Jobs de nettoyage et maintenance

#### `jobs/`

Jobs spécialisés organisés par fonction :

- **`validate/`** : Jobs de validation
  - Syntaxe Terraform/Ansible
  - Conformité des versions
  - Tests de sécurité

- **`plan/`** : Jobs de planification Terraform
  - Génération des plans par environnement
  - Validation des changements
  - Rapports d'impact

- **`apply/`** : Jobs d'application
  - Déploiement infrastructure
  - Sauvegarde des états
  - Validation post-déploiement

- **`deploy/`** : Jobs de déploiement applicatif
  - Exécution playbooks Ansible
  - Configuration services
  - Tests d'intégration

### 📁 `.gitlab/scripts/`

Scripts bash externalisés pour améliorer :

- **Testabilité** : Scripts indépendants testables
- **Réutilisabilité** : Appel depuis plusieurs jobs
- **Lisibilité** : Logique complexe hors des YAML

#### `terraform/`

- `install-terraform.sh` : Installation avec cache optimisé
- `validate-syntax.sh` : Validation syntaxique complète
- `plan-environment.sh` : Génération plan paramétrable
- `apply-environment.sh` : Application sécurisée

#### `ansible/`

- `setup-inventory.sh` : Configuration inventaires dynamiques
- `run-playbook.sh` : Exécution playbooks avec validation
- `test-connectivity.sh` : Tests de connectivité cibles

#### `utils/`

- `common.sh` : Fonctions partagées (logging, validation)
- `security-checks.sh` : Vérifications sécurité
- `performance-metrics.sh` : Collecte métriques pipeline

## 🔄 Migration depuis l'ancien pipeline

### Phase actuelle

- ✅ Structure de base créée
- ⏳ Migration des composants en cours

### Prochaines étapes

1. Extraction des variables globales → `includes/variables.yml`
2. Migration des templates → `includes/templates.yml`
3. Modularisation des jobs Terraform
4. Externalisation des scripts bash
5. Tests et validation de la structure

## 📝 Conventions

### Nommage des fichiers

- **Modules** : `nom-module.yml` (kebab-case)
- **Scripts** : `action-contexte.sh` (kebab-case)
- **Jobs** : Préfixe par fonction (`validate_`, `plan_`, etc.)

### Structure des jobs

```yaml
job_name:
  extends: .template_base
  stage: stage_name
  variables:
    ENV: environment
  script:
    - .gitlab/scripts/category/action.sh

