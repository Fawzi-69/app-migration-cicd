output "vpc_id" {
  description = "Identifiant de la VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Identifiants des sous-réseaux publics (ALB)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Identifiants des sous-réseaux privés (Fargate, RDS)."
  value       = aws_subnet.private[*].id
}

output "vpc_cidr" {
  description = "Bloc CIDR de la VPC."
  value       = aws_vpc.this.cidr_block
}
