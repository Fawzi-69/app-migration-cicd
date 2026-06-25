output "alb_dns_name" {
  description = "Point d'entrée HTTP(S) de l'application."
  value       = module.ecs_service.alb_dns_name
}

output "ecr_repository_url" {
  description = "Dépôt ECR où pousser l'image (utilisé par la CI)."
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS."
  value       = module.ecs_service.cluster_name
}

output "ecs_service_name" {
  description = "Nom du service ECS (cible du déploiement CI)."
  value       = module.ecs_service.service_name
}

output "ci_role_arn" {
  description = "Rôle à assumer par la CI GitLab (variable AWS_ROLE_ARN)."
  value       = module.ci_role.role_arn
}

output "rds_endpoint" {
  description = "Endpoint de la base PostgreSQL."
  value       = module.rds.endpoint
}

output "rds_master_secret_arn" {
  description = "ARN du secret des identifiants maîtres RDS (géré par AWS)."
  value       = module.rds.master_user_secret_arn
}
