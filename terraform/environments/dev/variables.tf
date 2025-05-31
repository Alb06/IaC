# =============================================================================
# VARIABLES ENVIRONNEMENT DE DÉVELOPPEMENT
# =============================================================================

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "dev"
  
  validation {
    condition     = var.environment == "dev"
    error_message = "Cette configuration est spécifique à l'environnement 'dev'."
  }
}

variable "override_server_ip" {
  description = "IP de serveur personnalisée (surcharge la valeur par défaut)"
  type        = string
  default     = null
  
  validation {
    condition = var.override_server_ip == null || can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.override_server_ip))
    error_message = "L'adresse IP doit être au format IPv4 valide."
  }
}

variable "custom_tags" {
  description = "Tags personnalisés spécifiques à dev"
  type        = map(string)
  default = {
    cost_center = "development"
    auto_start  = "true"
    auto_stop   = "true"
  }
}

variable "enable_monitoring" {
  description = "Activer le monitoring avancé en dev"
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Activer les sauvegardes en dev"
  type        = bool
  default     = false  # Pas de backup par défaut en dev
}

# Variables legacy (deprecated, à supprimer après migration)
variable "server_ip" {
  description = "DEPRECATED: Utiliser override_server_ip à la place"
  type        = string
  default     = null
  
  validation {
    condition     = var.server_ip == null
    error_message = "Variable 'server_ip' deprecated. Utilisez 'override_server_ip' à la place."
  }
}