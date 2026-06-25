variable "name" {
  description = "Préfixe de nommage des ressources réseau (ex. app-migration-cicd-dev)."
  type        = string
}

variable "cidr" {
  description = "Bloc CIDR de la VPC."
  type        = string
}

variable "azs" {
  description = "Zones de disponibilité à utiliser (ex. [\"eu-west-3a\", \"eu-west-3b\"])."
  type        = list(string)
}

variable "public_subnets" {
  description = "Blocs CIDR des sous-réseaux publics (un par AZ)."
  type        = list(string)
}

variable "private_subnets" {
  description = "Blocs CIDR des sous-réseaux privés (un par AZ)."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = <<-EOT
    true  : une seule NAT Gateway partagée (moins cher, conseillé en dev).
    false : une NAT Gateway par AZ (haute dispo, conseillé en prod).
  EOT
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Rétention (jours) des VPC Flow Logs dans CloudWatch."
  type        = number
  default     = 30
}
