output "repository_url" {
  description = "URL du dépôt ECR (utilisée pour tagger/pousser l'image)."
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN du dépôt ECR (référencé dans les politiques IAM)."
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Nom du dépôt ECR."
  value       = aws_ecr_repository.this.name
}
