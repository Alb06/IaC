output "environment_name" {
  description = "Nom de l'environnement déployé"
  value       = var.environment
}

output "test_file_path" {
  description = "Chemin du fichier de test créé"
  value       = local_file.test.filename
}