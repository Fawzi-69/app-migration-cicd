output "role_arn" {
  description = "ARN du rôle à assumer côté CI GitLab (variable AWS_ROLE_ARN du pipeline)."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Nom du rôle."
  value       = aws_iam_role.this.name
}
