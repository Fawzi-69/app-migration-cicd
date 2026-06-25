# --- Identité de l'environnement -------------------------------------------
variable "aws_region" {
  description = "Région AWS de l'environnement."
  type        = string
  default     = "eu-west-3"
}

variable "project" {
  description = "Nom du projet (tag Project + préfixe de nommage)."
  type        = string
  default     = "app-migration-cicd"
}

variable "env" {
  description = "Nom de l'environnement (dev|prod), utilisé en tag et préfixe."
  type        = string
}

variable "owner" {
  description = "Propriétaire/équipe (tag Owner)."
  type        = string
  default     = "fawzi"
}

# --- Réseau -----------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR de la VPC."
  type        = string
}

variable "azs" {
  description = "Zones de disponibilité."
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR des sous-réseaux publics."
  type        = list(string)
}

variable "private_subnets" {
  description = "CIDR des sous-réseaux privés."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "NAT unique (dev) ou une par AZ (prod)."
  type        = bool
  default     = true
}

# --- Application / ECS ------------------------------------------------------
variable "image_tag" {
  description = "Tag de l'image conteneur à déployer (ex. SHA de commit). 'latest' par défaut."
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Port exposé par le conteneur."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU de la tâche Fargate."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Mémoire de la tâche Fargate (Mo)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Nombre de tâches souhaité."
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Tâches minimales (autoscaling)."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Tâches maximales (autoscaling)."
  type        = number
  default     = 6
}

variable "certificate_arn" {
  description = "Certificat ACM pour HTTPS sur l'ALB (null = HTTP seul)."
  type        = string
  default     = null
}

# --- Base de données --------------------------------------------------------
variable "rds_instance_class" {
  description = "Classe d'instance RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_multi_az" {
  description = "Multi-AZ pour RDS (haute dispo)."
  type        = bool
  default     = false
}

variable "rds_deletion_protection" {
  description = "Protection contre la suppression de l'instance RDS."
  type        = bool
  default     = true
}

# --- CI/CD OIDC -------------------------------------------------------------
variable "gitlab_project_path" {
  description = "Chemin du projet GitLab (groupe/projet) autorisé à assumer le rôle CI."
  type        = string
}

variable "gitlab_branch" {
  description = "Branche GitLab autorisée à déployer cet environnement."
  type        = string
}

variable "oidc_provider_host" {
  description = "Hôte du fournisseur OIDC GitLab."
  type        = string
  default     = "gitlab.com"
}

variable "oidc_aud" {
  description = "Audience attendue dans le jeton OIDC."
  type        = string
  default     = "https://gitlab.com"
}

variable "additional_ci_policy_arns" {
  description = "Politiques gérées supplémentaires pour le rôle CI (ex. apply infra)."
  type        = list(string)
  default     = []
}

# --- Backend / state (pour les permissions du rôle CI) ----------------------
variable "state_bucket_name" {
  description = "Nom du bucket S3 des states (créé par le bootstrap)."
  type        = string
}

variable "lock_table_name" {
  description = "Nom de la table DynamoDB de verrou."
  type        = string
}

variable "state_kms_key_arn" {
  description = "ARN de la clé KMS chiffrant le state (sortie du bootstrap). Optionnel."
  type        = string
  default     = null
}
