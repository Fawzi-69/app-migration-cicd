output "state_bucket_name" {
  description = "Nom du bucket S3 des states (à passer en -backend-config bucket=...)."
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table_name" {
  description = "Nom de la table DynamoDB de verrou (à passer en -backend-config dynamodb_table=...)."
  value       = aws_dynamodb_table.tf_locks.name
}

output "kms_key_arn" {
  description = "ARN de la clé KMS chiffrant les states."
  value       = aws_kms_key.tfstate.arn
}

output "gitlab_oidc_provider_arn" {
  description = "ARN du fournisseur OIDC GitLab (consommé par les rôles de déploiement)."
  value       = aws_iam_openid_connect_provider.gitlab.arn
}

output "ecr_repository_url" {
  description = "URL du dépôt ECR partagé (utilisée par la CI pour pousser l'image)."
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN du dépôt ECR partagé (référencé par les rôles CI des environnements)."
  value       = module.ecr.repository_arn
}
