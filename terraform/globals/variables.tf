# =============================================================================
# VARIABLES D'ENTRÉE DU MODULE GLOBALS
# =============================================================================

variable "environment" {
  description = "Environnement de déploiement (dev, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev' ou 'prod'."
  }
}

variable "override_server_ip" {
  description = "IP de serveur personnalisée (optionnel)"
  type        = string
  default     = null
  
  validation {
    condition = var.override_server_ip == null || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.override_server_ip))
    error_message = "L'adresse IP doit être au format IPv4 valide."
  }
}

variable "custom_tags" {
  description = "Tags personnalisés à ajouter aux ressources"
  type        = map(string)
  default     = {}
}

variable "enable_monitoring" {
  description = "Activer le monitoring avancé"
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Activer les sauvegardes automatiques"
  type        = bool
  default     = true
}