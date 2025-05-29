# Configuration du provider
terraform {
  required_version = ">= 1.12.1"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# Exemple de ressource simple pour tester
resource "local_file" "test" {
  content  = "Hello from Terraform in dev environment!"
  filename = "${path.module}/test-file.txt"
}