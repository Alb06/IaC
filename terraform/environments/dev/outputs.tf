output "environment_name" {
  description = "Nom de l'environnement d�ploy�"
  value       = var.environment
}

output "test_file_path" {
  description = "Chemin du fichier de test cr��"
  value       = local_file.test.filename
}