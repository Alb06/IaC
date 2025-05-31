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

# Informations pour GitLab CI/CD
output "cicd_variables" {
  description = "Variables pour GitLab CI/CD"
  value = {
    TF_VERSION      = local.versions.terraform
    K3S_VERSION     = local.versions.k3s
    HELM_VERSION    = local.versions.helm
    ANSIBLE_VERSION = local.versions.ansible
    SERVER_IP       = var.override_server_ip != null ? var.override_server_ip : local.current_server.ip
    ENVIRONMENT     = var.environment
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