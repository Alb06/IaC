# =============================================================================
# MODULE TERRAFORM GLOBALS - Variables Centralisées Infrastructure IaC
# =============================================================================
# Description : Source unique de vérité pour toutes les configurations
# Auteur      : Infrastructure Team
# Version     : 1.2.0 - Ajout configuration monitoring Prometheus
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
    kubectl      = "v1.33.1"
    prometheus   = "v2.53.0"  # 🆕 Version Prometheus
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
    ssh           = 22
    http          = 80
    https         = 443
    k3s_api       = 6443
    postgresql    = 5432
    gitlab_runner = 8093
    redis         = 6379
    memcached     = 11211
    prometheus    = 9090      # 🆕 Port Prometheus
    grafana       = 3000      # 🆕 Port Grafana (pour futur usage)
    alertmanager  = 9093      # 🆕 Port AlertManager (pour futur usage)
  }

  # Configuration Docker
  docker = {
    registry     = "registry.gitlab.com"
    network_name = "homelab-network"
    volumes_path = "/opt/docker/volumes"
  }

  # 🆕 Configuration Kubernetes étendue avec monitoring
  kubernetes = {
    cluster_name     = "homelab-k3s"
    # Namespaces étendus avec les nouveaux
    namespace_default    = "default"
    namespace_monitoring = "monitoring"
    namespace_ingress    = "ingress-nginx"
    namespace_automation = "automation"
    namespace_databases  = "databases"
    namespace_cache      = "cache"
    
    # Storage classes disponibles
    storage_class        = "local-path"
    storage_class_ssd    = "local-ssd-fast"
    storage_class_standard = "local-standard"
    storage_class_backup = "local-backup"
    
    # Configuration des quotas par namespace
    quotas = {
      automation = {
        cpu_requests    = "2"
        memory_requests = "4Gi"
        cpu_limits      = "4"
        memory_limits   = "8Gi"
        storage         = "50Gi"
      }
      databases = {
        cpu_requests    = "4"
        memory_requests = "8Gi"
        cpu_limits      = "8"
        memory_limits   = "16Gi"
        storage         = "100Gi"
      }
      cache = {
        cpu_requests    = "2"
        memory_requests = "4Gi"
        cpu_limits      = "4"
        memory_limits   = "8Gi"
        storage         = "20Gi"
      }
      monitoring = {
        cpu_requests    = "3"
        memory_requests = "6Gi"
        cpu_limits      = "6"
        memory_limits   = "12Gi"
        storage         = "200Gi"
      }
    }
  }

  # 🆕 Configuration Monitoring centralisée
  monitoring = {
    # Configuration Prometheus
    prometheus = {
      version = local.versions.prometheus
      port    = local.ports.prometheus
      storage = {
        class = local.kubernetes.storage_class_ssd
        size = var.environment == "prod" ? "200Gi" : "100Gi"
      }
      retention = {
        time = var.environment == "prod" ? "30d" : "7d"
        size = var.environment == "prod" ? "180GiB" : "90GiB"
      }
      resources = var.environment == "prod" ? {
        requests = { cpu = "1000m", memory = "2Gi" }
        limits   = { cpu = "2000m", memory = "4Gi" }
      } : {
        requests = { cpu = "500m", memory = "1Gi" }
        limits   = { cpu = "1000m", memory = "2Gi" }
      }
      service_account = "monitoring-sa"
    }
    
    # Configuration pour futurs composants
    grafana = {
      version = "11.4.0"  # Pour future implémentation
      port    = local.ports.grafana
      domain  = "grafana.${local.network.domain}"
      storage = {
        class = local.kubernetes.storage_class_ssd
        size  = "20Gi"
      }
    }
    
    alertmanager = {
      version = "v0.27.0"  # Pour future implémentation
      port    = local.ports.alertmanager
      storage = {
        class = local.kubernetes.storage_class_standard
        size  = "10Gi"
      }
    }
    
    # Configuration générale
    namespace = local.kubernetes.namespace_monitoring
    service_account = "monitoring-sa"
    scrape_interval = "30s"
    evaluation_interval = "30s"
    
    # Labels pour l'auto-découverte
    labels = {
      monitoring = "prometheus"
      component  = "monitoring-stack"
    }
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
      # Configuration K8s dev
      kubernetes_quotas_enabled = false
      network_policies_enabled  = false
      # 🆕 Configuration monitoring dev
      monitoring_retention = "7d"
      monitoring_storage   = "100Gi"
    }
    prod = {
      replicas          = 2
      resource_requests = "guaranteed"
      backup_retention  = "30d"
      monitoring_level  = "full"
      auto_scaling     = true
      # Configuration K8s prod
      kubernetes_quotas_enabled = true
      network_policies_enabled  = true
      # 🆕 Configuration monitoring prod
      monitoring_retention = "30d"
      monitoring_storage   = "200Gi"
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