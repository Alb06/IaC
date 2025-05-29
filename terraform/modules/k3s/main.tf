# Module Terraform pour installation K3s
# terraform/modules/k3s/main.tf

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Variables du module
variable "server_ip" {
  description = "IP du serveur Ubuntu"
  type        = string
}

variable "ssh_user" {
  description = "Utilisateur SSH"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Chemin vers la clé SSH privée"
  type        = string
}

variable "k3s_version" {
  description = "Version de K3s à installer"
  type        = string
  default     = "v1.28.5+k3s1"
}

# Installation de K3s via remote-exec
resource "null_resource" "k3s_installation" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    host        = var.server_ip
    private_key = file(var.ssh_private_key_path)
  }

  # Script d'installation K3s
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y curl",
      "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION='${var.k3s_version}' sh -s - server --write-kubeconfig-mode 644 --disable traefik --disable servicelb --node-name homelab-master",
      "sudo systemctl enable k3s",
      "sudo systemctl start k3s",
      "mkdir -p ~/.kube",
      "sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config",
      "sudo chown $USER:$USER ~/.kube/config",
      "chmod 600 ~/.kube/config",
      # Attendre que K3s soit prêt
      "sleep 30",
      "kubectl get nodes"
    ]
  }

  # Récupération du kubeconfig
  provisioner "local-exec" {
    command = <<-EOT
      scp -i ${var.ssh_private_key_path} -o StrictHostKeyChecking=no ${var.ssh_user}@${var.server_ip}:~/.kube/config ./kubeconfig-${var.server_ip}
      sed -i 's/127.0.0.1/${var.server_ip}/g' ./kubeconfig-${var.server_ip}
    EOT
  }
}

# Outputs
output "kubeconfig_path" {
  description = "Chemin vers le fichier kubeconfig"
  value       = "./kubeconfig-${var.server_ip}"
}

output "cluster_endpoint" {
  description = "Endpoint du cluster K3s"
  value       = "https://${var.server_ip}:6443"
}

output "installation_status" {
  description = "Statut de l'installation"
  value       = "K3s installé sur ${var.server_ip}"
  depends_on  = [null_resource.k3s_installation]
}