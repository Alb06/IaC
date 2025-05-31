# =============================================================================
# OUTPUTS ENVIRONNEMENT DE PRODUCTION
# =============================================================================

# Outputs classiques
output "environment_name" {
  description = "Nom de l'environnement deploye"
  value       = var.environment
}

output "test_file_path" {
  description = "Chemin du fichier de test cree"
  value       = local_file.test.filename
}

# Outputs du module globals
output "server_config" {
  description = "Configuration complète du serveur prod"
  value       = module.globals.server
  sensitive   = false  # Pas d'infos sensibles
}

output "versions" {
  description = "Versions des outils utilisées"
  value       = module.globals.versions
}

output "network_config" {
  description = "Configuration réseau (infos publiques uniquement)"
  value = {
    domain        = module.globals.network.domain
    subnet        = module.globals.network.subnet
    # IP publiques masquées pour la sécurité
  }
}

output "endpoints" {
  description = "URLs et endpoints des services"
  value = {
    base_url = module.globals.endpoints.base_url
    # SSH et API endpoints masqués en prod
  }
  sensitive = true
}

output "ansible_inventory_path" {
  description = "Chemin vers l'inventaire Ansible généré"
  value       = local_file.ansible_inventory.filename
}

output "cicd_variables" {
  description = "Variables pour GitLab CI/CD"
  value       = module.globals.cicd_variables
  sensitive   = false
}

output "backup_config_path" {
  description = "Chemin vers la configuration de sauvegarde"
  value       = local_file.backup_config.filename
}

# Output pour validation production
output "infrastructure_summary" {
  description = "Résumé de l'infrastructure prod"
  value = {
    environment = var.environment
    server = {
      name = module.globals.server.name
      fqdn = module.globals.server.fqdn
      # IP masquée en prod pour la sécurité
    }
    versions = {
      terraform = module.globals.versions.terraform
      k3s       = module.globals.versions.k3s
      helm      = module.globals.versions.helm
    }
    security = {
      monitoring_enabled = var.enable_monitoring
      backup_enabled    = var.backup_enabled
      ha_mode          = true
    }
    ansible_inventory = local_file.ansible_inventory.filename
    last_updated     = timestamp()
  }
}