# =============================================================================
# OUTPUTS DU MODULE GLOBALS
# =============================================================================

# Configuration serveur actuel
output "server" {
  description = "Configuration complète du serveur pour l'environnement"
  value = {
    name        = local.current_server.name
    ip          = var.override_server_ip != null ? var.override_server_ip : local.current_server.ip
    fqdn        = local.server_fqdn
    description = local.current_server.description
    specs       = local.current_server.specs
  }
}

# Tous les serveurs (pour inventaires cross-env)
output "servers" {
  description = "Configuration de tous les serveurs"
  value       = local.servers
}

# Versions des outils
output "versions" {
  description = "Versions standardisées de tous les outils"
  value       = local.versions
}

# =============================================================================
# 🆕 NOUVEAUX OUTPUTS POUR LES CONTRAINTES DE VERSIONS
# =============================================================================

# Contraintes Terraform centralisées (depuis versions.tf)
output "terraform_constraints" {
  description = "Contraintes de versions Terraform et providers centralisées"
  value       = local.terraform_constraints
}

# Métadonnées de gestion des versions
output "version_metadata" {
  description = "Métadonnées et informations sur la gestion des versions"
  value       = local.version_metadata
}

# Validation des contraintes appliquées
output "version_validation" {
  description = "Statut de validation des contraintes de versions"
  value = {
    terraform_version_valid = can(regex("^>= 1\\.12\\.1", local.terraform_constraints.terraform_version))
    providers_count        = length(local.terraform_constraints.provider_versions)
    last_validation       = timestamp()
  }
}

# =============================================================================
# OUTPUTS EXISTANTS
# =============================================================================

# Configuration réseau
output "network" {
  description = "Configuration réseau globale"
  value       = local.network
}

# Ports standards
output "ports" {
  description = "Ports standards des services"
  value       = local.ports
}

# Configuration Docker
output "docker" {
  description = "Configuration Docker standardisée"
  value       = local.docker
}

# Configuration Kubernetes
output "kubernetes" {
  description = "Configuration Kubernetes/K3s"
  value       = local.kubernetes
}

# Tags communs
output "common_tags" {
  description = "Tags communs pour toutes les ressources"
  value       = merge(local.common_tags, var.custom_tags)
}

# Configuration environnement
output "environment_config" {
  description = "Configuration spécifique à l'environnement"
  value       = local.current_config
}

# Configuration Ansible
output "ansible_config" {
  description = "Configuration pour l'intégration Ansible"
  value       = local.ansible_config
}

# Informations pour GitLab CI/CD (mise à jour avec contraintes)
output "cicd_variables" {
  description = "Variables pour GitLab CI/CD incluant les contraintes de versions"
  value = {
    TF_VERSION      = local.versions.terraform
    K3S_VERSION     = local.versions.k3s
    HELM_VERSION    = local.versions.helm
    ANSIBLE_VERSION = local.versions.ansible
    SERVER_IP       = var.override_server_ip != null ? var.override_server_ip : local.current_server.ip
    ENVIRONMENT     = var.environment
    # Nouvelles variables pour les contraintes
    TF_REQUIRED_VERSION = local.terraform_constraints.terraform_version
    TF_PROVIDER_LOCAL   = local.terraform_constraints.provider_versions.local
    TF_PROVIDER_NULL    = local.terraform_constraints.provider_versions.null
  }
}

# URL et endpoints calculés
output "endpoints" {
  description = "URLs et endpoints des services"
  value = {
    server_ssh = "ssh://ubuntu@${var.override_server_ip != null ? var.override_server_ip : local.current_server.ip}:${local.ports.ssh}"
    k3s_api    = "https://${var.override_server_ip != null ? var.override_server_ip : local.current_server.ip}:${local.ports.k3s_api}"
    base_url   = "https://${local.server_fqdn}"
  }
}