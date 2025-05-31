# =============================================================================
# GÉNÉRATION AUTOMATIQUE INVENTAIRE ANSIBLE - ENVIRONNEMENT PROD
# =============================================================================
# Description : Génère l'inventaire Ansible dynamiquement depuis les variables globals
# Fichier cible : ansible/inventory/prod
# =============================================================================

# Génération de l'inventaire Ansible pour l'environnement prod
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../../templates/inventory.tpl", {
    environment     = var.environment
    server         = module.globals.server
    servers        = module.globals.servers
    network        = module.globals.network
    ports          = module.globals.ports
    versions       = module.globals.versions
    docker         = module.globals.docker
    kubernetes     = module.globals.kubernetes
    ansible_config = module.globals.ansible_config
    timestamp      = timestamp()
  })
  
  filename        = "${path.module}/../../../ansible/inventory/${var.environment}"
  file_permission = "0644"
  
  # Force la régénération à chaque apply pour garantir la cohérence
  depends_on = [module.globals]
}

# Sauvegarde de l'ancien inventaire avant remplacement
resource "local_file" "ansible_inventory_backup" {
  content = fileexists("${path.module}/../../../ansible/inventory/${var.environment}") ? file("${path.module}/../../../ansible/inventory/${var.environment}") : "# Pas d'inventaire existant"
    
  filename = "${path.module}/../../../ansible/inventory/${var.environment}.backup.${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  
  # Ne créer la sauvegarde que si l'inventaire original existe
  count = fileexists("${path.module}/../../../ansible/inventory/${var.environment}") ? 1 : 0
}

# Validation spécifique production
resource "null_resource" "validate_ansible_inventory_prod" {
  depends_on = [local_file.ansible_inventory]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Validation de l'inventaire Ansible PRODUCTION..."
      
      # Vérifications spécifiques production
      inventory_file="${local_file.ansible_inventory.filename}"
      
      # Vérification que le fichier existe et n'est pas vide
      if [ ! -s "$inventory_file" ]; then
        echo "ERREUR: Fichier d'inventaire vide ou inexistant"
        exit 1
      fi
      
      # Vérification IP de production
      if ! grep -q "192.168.1.64" "$inventory_file"; then
        echo "ERREUR: IP de production non trouvée dans l'inventaire"
        exit 1
      fi
      
      # Vérification configuration de sécurité prod
      if ! grep -q "deployment_type=production" "$inventory_file"; then
        echo "ERREUR: Configuration production non détectée"
        exit 1
      fi
      
      # Test de syntaxe avec ansible-inventory (si disponible)
      if command -v ansible-inventory >/dev/null 2>&1; then
        ansible-inventory -i "$inventory_file" --list >/dev/null
        if [ $? -eq 0 ]; then
          echo "✅ Syntaxe de l'inventaire production validée"
        else
          echo "❌ Erreur de syntaxe dans l'inventaire production"
          exit 1
        fi
      else
        echo "⚠️  ansible-inventory non disponible, validation syntaxique ignorée"
      fi
      
      echo "✅ Inventaire production généré et validé : $inventory_file"
    EOT
    
    working_dir = path.module
  }
  
  triggers = {
    inventory_content = local_file.ansible_inventory.content
  }
}