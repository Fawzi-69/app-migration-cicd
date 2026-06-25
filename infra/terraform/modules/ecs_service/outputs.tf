output "alb_dns_name" {
  description = "Nom DNS public de l'ALB (point d'entrée de l'application)."
  value       = aws_lb.this.dns_name
}

output "cluster_name" {
  description = "Nom du cluster ECS."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "Nom du service ECS (utilisé par la CI pour forcer un déploiement)."
  value       = aws_ecs_service.this.name
}

output "task_security_group_id" {
  description = "SG des tâches Fargate (à autoriser en entrée côté RDS)."
  value       = aws_security_group.tasks.id
}

output "task_definition_arn" {
  description = "ARN de la task definition active."
  value       = aws_ecs_task_definition.this.arn
}

output "log_group_name" {
  description = "Groupe de logs CloudWatch des conteneurs."
  value       = aws_cloudwatch_log_group.app.name
}

output "execution_role_arn" {
  description = "ARN du rôle d'exécution (transmis à ECS via iam:PassRole)."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN du rôle de tâche (transmis à ECS via iam:PassRole)."
  value       = aws_iam_role.task.arn
}
