# =============================================================================
# GÉNÉRATION AUTOMATIQUE INVENTAIRE ANSIBLE - ENVIRONNEMENT DEV
# =============================================================================
# Description : Génère l'inventaire Ansible dynamiquement depuis les variables globals
# Fichier cible : ansible/inventory/dev
# =============================================================================

# Génération de l'inventaire Ansible pour l'environnement dev
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

# Validation de la syntaxe de l'inventaire généré
resource "null_resource" "validate_ansible_inventory" {
  depends_on = [local_file.ansible_inventory]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Validation de l'inventaire Ansible généré..."
      
      # Vérification que le fichier existe et n'est pas vide
      if [ ! -s "${local_file.ansible_inventory.filename}" ]; then
        echo "ERREUR: Fichier d'inventaire vide ou inexistant"
        exit 1
      fi
      
      # Test de syntaxe avec ansible-inventory (si disponible)
      if command -v ansible-inventory >/dev/null 2>&1; then
        ansible-inventory -i "${local_file.ansible_inventory.filename}" --list >/dev/null
        if [ $? -eq 0 ]; then
          echo "✅ Syntaxe de l'inventaire validée"
        else
          echo "❌ Erreur de syntaxe dans l'inventaire"
          exit 1
        fi
      else
        echo "⚠️  ansible-inventory non disponible, validation syntaxique ignorée"
      fi
      
      echo "Inventaire généré avec succès : ${local_file.ansible_inventory.filename}"
    EOT
    
    working_dir = path.module
  }
  
  triggers = {
    inventory_content = local_file.ansible_inventory.content
  }
}