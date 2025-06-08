# =============================================================================
# ENVIRONNEMENT DE PRODUCTION - CONFIGURATION TERRAFORM
# =============================================================================
# Description : Configuration Terraform pour l'environnement de production
# Utilise le module globals pour la centralisation des variables
# NOTE: Les contraintes Terraform sont définies dans versions.tf
# =============================================================================


# =============================================================================
# MODULE GLOBALS - VARIABLES CENTRALISÉES
# =============================================================================

module "globals" {
  source = "../../globals"
  
  environment      = var.environment
  override_server_ip = var.override_server_ip
  custom_tags      = var.custom_tags
  enable_monitoring = var.enable_monitoring
  backup_enabled   = var.backup_enabled
}

# =============================================================================
# VARIABLES LOCALES CALCULÉES
# =============================================================================

locals {
  # Configuration serveur depuis globals
  server_config = module.globals.server
  versions      = module.globals.versions
  network       = module.globals.network
  common_tags   = module.globals.common_tags
  
  # Configuration spécifique prod
  env_config = module.globals.environment_config
  
  # 🆕 Nouvelles variables pour les contraintes de versions
  terraform_constraints = module.globals.terraform_constraints
  version_metadata     = module.globals.version_metadata
}

# =============================================================================
# RESSOURCES TERRAFORM
# =============================================================================

# Fichier de test pour validation du déploiement
resource "local_file" "test" {
  content = templatefile("${path.module}/../../templates/test-file.tpl", {
    environment    = var.environment
    server        = local.server_config
    versions      = local.versions
    network       = local.network
    timestamp     = timestamp()
  })
  filename = "${path.module}/test-file.txt"
  
  file_permission = "0644"
}

# Configuration K3s production avec haute disponibilité
resource "local_file" "k3s_config" {
  content = templatefile("${path.module}/../../templates/k3s-config.tpl", {
    cluster_name = module.globals.kubernetes.cluster_name
    server_ip   = local.server_config.ip
    api_port    = module.globals.ports.k3s_api
    version     = local.versions.k3s
    ha_enabled  = true  # Prod spécifique
  })
  filename = "${path.module}/k3s-config.yaml"
  
  file_permission = "0600"
}

# Configuration de sauvegarde production
resource "local_file" "backup_config" {
  content = <<-EOT
# Configuration de sauvegarde pour ${var.environment}
BACKUP_ENABLED=${var.backup_enabled}
BACKUP_RETENTION=${module.globals.common_tags.backup_policy}
BACKUP_SCHEDULE="0 2 * * *"  # Tous les jours à 2h
BACKUP_DESTINATION="/opt/backups"
CLUSTER_NAME=${module.globals.kubernetes.cluster_name}
DATABASE_BACKUP=true
VOLUME_BACKUP=true
EOT

  filename = "${path.module}/backup-config.env"
  file_permission = "0600"
}

# Variables d'environnement pour les scripts
resource "local_file" "env_vars" {
  content = <<-EOT
# Variables d'environnement pour ${var.environment}
export ENVIRONMENT=${var.environment}
export SERVER_IP=${local.server_config.ip}
export SERVER_NAME=${local.server_config.name}
export K3S_VERSION=${local.versions.k3s}
export TERRAFORM_VERSION=${local.versions.terraform}
export HELM_VERSION=${local.versions.helm}
export CLUSTER_NAME=${module.globals.kubernetes.cluster_name}
export DOMAIN=${local.network.domain}
export MONITORING_ENABLED=${var.enable_monitoring}
export BACKUP_ENABLED=${var.backup_enabled}
export HA_MODE=true

# 🆕 Variables contraintes Terraform
export TF_REQUIRED_VERSION="${local.terraform_constraints.terraform_version}"
export TF_PROVIDER_LOCAL="${local.terraform_constraints.provider_versions.local}"
export TF_PROVIDER_NULL="${local.terraform_constraints.provider_versions.null}"
EOT

  filename = "${path.module}/.env"
  file_permission = "0644"
}

# 🆕 Fichier de validation des contraintes de versions (spécifique prod)
resource "local_file" "version_constraints" {
  content = jsonencode({
    terraform_constraints = local.terraform_constraints
    version_metadata     = local.version_metadata
    validation_status    = module.globals.version_validation
    production_specific = {
      ha_enabled        = true
      monitoring_enabled = var.enable_monitoring
      backup_enabled    = var.backup_enabled
      security_level    = "high"
    }
    generated_at = timestamp()
  })
  
  filename = "${path.module}/version-constraints.json"
  file_permission = "0644"
}