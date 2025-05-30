variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "dev"
}

variable "server_ip" {
  description = "Adresse IP du serveur cible"
  type        = string
  default     = "192.168.1.63"
}