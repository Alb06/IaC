# =============================================================================
# CONTRAINTES DE VERSIONS - ENVIRONNEMENT DÉVELOPPEMENT
# =============================================================================
# Description : Contraintes héritées du module globals
# Environnement : dev
# Source : terraform/globals/versions.tf
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
# CONFIGURATION SPÉCIFIQUE DEV (si nécessaire à l'avenir)
# =============================================================================

# Espace réservé pour des contraintes spécifiques dev si nécessaires
# Actuellement : contraintes identiques à prod pour la cohérence