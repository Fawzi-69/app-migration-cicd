output "secret_arns" {
  description = "Map nom_logique => ARN du secret (injecté dans la task definition ECS)."
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.arn }
}

output "secret_names" {
  description = "Map nom_logique => nom complet du secret."
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.name }
}
