# =============================================================================
# GESTION CENTRALISÉE DES VERSIONS TERRAFORM ET PROVIDERS
# =============================================================================
# Description : Source unique de vérité pour toutes les contraintes de versions
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

terraform {
  required_version = ">= 1.12.1, < 2.0.0"
  
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# =============================================================================
# VARIABLES LOCALES POUR CONTRAINTES DE VERSIONS
# =============================================================================

locals {
  # Contraintes Terraform et Providers (référence pour les environnements)
  terraform_constraints = {
    terraform_version = ">= 1.12.1, < 2.0.0"
    provider_versions = {
      local = "~> 2.5"
      null  = "~> 3.2"
    }
  }
  
  # Métadonnées de gestion des versions
  version_metadata = {
    last_updated     = "2025-06-07"
    terraform_docs   = "https://developer.hashicorp.com/terraform/language/expressions/version-constraints"
    breaking_changes = "Version 2.0.0+ non supportée - migration requise"
    notes           = "Contraintes utilisées par tous les environnements (dev, prod)"
  }
}