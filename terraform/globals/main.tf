# =============================================================================
# MODULE TERRAFORM GLOBALS - Variables Centralisées Infrastructure IaC
# =============================================================================
# Description : Source unique de vérité pour toutes les configurations
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# NOTE: Les contraintes Terraform sont maintenant dans versions.tf

# =============================================================================
# VARIABLES GLOBALES CENTRALISÉES
# =============================================================================

locals {
  # Configuration des serveurs par environnement
  servers = {
    dev = {
      name        = "dev-server"
      ip          = "192.168.1.63"
      description = "Serveur de développement HomeLab"
      specs = {
        cpu    = 4
        memory = "8GB"
        disk   = "500GB"
      }
    }
    prod = {
      name        = "prod-server"
      ip          = "192.168.1.64"
      description = "Serveur de production HomeLab"
      specs = {
        cpu    = 4
        memory = "16GB"
        disk   = "500GB"
      }
    }
  }

  # Versions exactes des outils et services (maintenu depuis versions.tf)
  versions = {
    terraform     = "1.12.1"
    k3s          = "v1.33.1+k3s1"
    helm         = "3.18.1"
    ansible      = "2.18.6"
    docker       = "28.2.1"
    ubuntu       = "24.04"
    postgresql   = "17.5"
    gitlab_runner = "17.11.1"
  }

  # Configuration réseau globale
  network = {
    subnet        = "192.168.1.0/24"
    gateway       = "192.168.1.1"
    domain        = "homelab.local"
    dns_primary   = "192.168.1.1"
    dns_secondary = "8.8.8.8"
  }

  # Ports et services standards
  ports = {
    ssh        = 22
    http       = 80
    https      = 443
    k3s_api    = 6443
    postgresql = 5432
    gitlab_runner = 8093
  }

  # Configuration Docker
  docker = {
    registry     = "registry.gitlab.com"
    network_name = "homelab-network"
    volumes_path = "/opt/docker/volumes"
  }

  # Configuration Kubernetes
  kubernetes = {
    cluster_name     = "homelab-k3s"
    namespace_default = "default"
    namespace_monitoring = "monitoring"
    namespace_ingress = "ingress-nginx"
    storage_class    = "local-path"
  }

  # Labels et tags communs
  common_tags = {
    project        = "homelab-iac"
    managed_by     = "terraform"
    environment    = var.environment
    last_updated   = timestamp()
    cost_center    = "infrastructure"
    backup_policy  = var.environment == "prod" ? "daily" : "weekly"
  }

  # Configuration spécifique par environnement
  environment_config = {
    dev = {
      replicas           = 1
      resource_requests  = "minimal"
      backup_retention   = "7d"
      monitoring_level   = "basic"
      auto_scaling      = false
    }
    prod = {
      replicas          = 2
      resource_requests = "guaranteed"
      backup_retention  = "30d"
      monitoring_level  = "full"
      auto_scaling     = true
    }
  }

  # Validation et calculs dynamiques
  current_server = local.servers[var.environment]
  current_config = local.environment_config[var.environment]
  
  # Génération des FQDNs
  server_fqdn = "${local.current_server.name}.${local.network.domain}"
  
  # Configuration Ansible automatique
  ansible_config = {
    user           = "ubuntu"
    ssh_key_path   = "~/.ssh/id_rsa"
    python_interpreter = "/usr/bin/python3"
    gather_facts   = true
    host_key_checking = false
  }
}

# =============================================================================
# VALIDATION DES VARIABLES
# =============================================================================

# Validation de l'adresse IP
resource "null_resource" "validate_ip" {
  count = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", local.current_server.ip)) ? 0 : 1
  
  provisioner "local-exec" {
    command = "echo 'ERROR: Invalid IP address format for ${var.environment}: ${local.current_server.ip}' && exit 1"
  }
}

# Validation de l'environnement
resource "null_resource" "validate_environment" {
  count = contains(["dev", "prod"], var.environment) ? 0 : 1
  
  provisioner "local-exec" {
    command = "echo 'ERROR: Invalid environment. Must be dev or prod, got: ${var.environment}' && exit 1"
  }
}