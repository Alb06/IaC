# =============================================================================
# CONTRAINTES DE VERSIONS - ENVIRONNEMENT PRODUCTION
# =============================================================================
# Description : Contraintes héritées du module globals
# Environnement : prod
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
# CONFIGURATION SPÉCIFIQUE PRODUCTION
# =============================================================================

# Contraintes identiques à dev pour garantir la cohérence
# Aucune spécificité prod requise actuellement
# Évolution possible : contraintes plus strictes en prod si nécessaire