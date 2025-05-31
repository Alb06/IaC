# =============================================================================
# OUTPUTS ENVIRONNEMENT DE DÉVELOPPEMENT
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
  description = "Configuration complète du serveur dev"
  value       = module.globals.server
}

output "versions" {
  description = "Versions des outils utilisées"
  value       = module.globals.versions
}

output "network_config" {
  description = "Configuration réseau"
  value       = module.globals.network
}

output "endpoints" {
  description = "URLs et endpoints des services"
  value       = module.globals.endpoints
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

# Output pour validation
output "infrastructure_summary" {
  description = "Résumé de l'infrastructure dev"
  value = {
    environment = var.environment
    server = {
      name = module.globals.server.name
      ip   = module.globals.server.ip
      fqdn = module.globals.server.fqdn
    }
    versions = {
      terraform = module.globals.versions.terraform
      k3s       = module.globals.versions.k3s
      helm      = module.globals.versions.helm
    }
    ansible_inventory = local_file.ansible_inventory.filename
    last_updated     = timestamp()
  }
}