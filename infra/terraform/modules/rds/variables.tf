variable "identifier" {
  description = "Identifiant de l'instance RDS (ex. app-migration-cicd-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC hébergeant l'instance."
  type        = string
}

variable "subnet_ids" {
  description = "Sous-réseaux PRIVÉS du groupe de sous-réseaux DB (un par AZ)."
  type        = list(string)
}

variable "ingress_security_group_ids" {
  description = "SG autorisés à se connecter au port PostgreSQL (typiquement le SG des tâches ECS)."
  type        = list(string)
}

variable "engine_version" {
  description = "Version majeure.mineure de PostgreSQL."
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "Classe d'instance RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Stockage initial (Go)."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Plafond d'auto-scaling du stockage (Go)."
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Nom de la base créée à l'initialisation."
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Nom de l'utilisateur maître. Le mot de passe est géré par AWS Secrets Manager."
  type        = string
  default     = "appadmin"
}

variable "multi_az" {
  description = "Déploiement multi-AZ (haute dispo). Conseillé en prod."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Durée de rétention des sauvegardes automatiques (jours)."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Protège l'instance contre une suppression accidentelle."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN de la clé KMS pour le stockage chiffré et le secret du mot de passe. Si null, clé AWS par défaut."
  type        = string
  default     = null
}

variable "port" {
  description = "Port d'écoute PostgreSQL."
  type        = number
  default     = 5432
}

variable "monitoring_interval" {
  description = "Intervalle (s) du monitoring renforcé RDS (0 = désactivé ; 60 recommandé)."
  type        = number
  default     = 60
}
