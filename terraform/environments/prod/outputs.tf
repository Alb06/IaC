output "environment_name" {
  description = "Nom de l'environnement deploye"
  value       = var.environment
}

output "test_file_path" {
  description = "Chemin du fichier de test cree"
  value       = local_file.test.filename
}