output "endpoint" {
  description = "Endpoint de connexion (hôte:port) de l'instance."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Nom d'hôte de l'instance."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Port d'écoute."
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "SG de la base (référencé pour ouvrir le flux depuis l'application)."
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "ARN du secret Secrets Manager contenant les identifiants maîtres gérés par AWS."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "db_name" {
  description = "Nom de la base de données."
  value       = aws_db_instance.this.db_name
}
