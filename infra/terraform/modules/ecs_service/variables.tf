variable "name" {
  description = "Préfixe de nommage (ex. app-migration-cicd-dev)."
  type        = string
}

variable "aws_region" {
  description = "Région AWS (utilisée pour la configuration des logs awslogs)."
  type        = string
}

variable "vpc_id" {
  description = "VPC cible."
  type        = string
}

variable "public_subnet_ids" {
  description = "Sous-réseaux publics hébergeant l'ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Sous-réseaux privés hébergeant les tâches Fargate."
  type        = list(string)
}

variable "image" {
  description = "URI complète de l'image conteneur (dépôt:tag)."
  type        = string
}

variable "container_port" {
  description = "Port exposé par le conteneur."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "CPU de la tâche Fargate (unités ; 256 = 0,25 vCPU)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Mémoire de la tâche Fargate (Mo)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Nombre de tâches souhaité au démarrage."
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Nombre minimal de tâches (autoscaling)."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Nombre maximal de tâches (autoscaling)."
  type        = number
  default     = 6
}

variable "cpu_target_value" {
  description = "Cible d'utilisation CPU moyenne (%) déclenchant l'autoscaling."
  type        = number
  default     = 60
}

variable "environment" {
  description = "Variables d'environnement non sensibles injectées dans le conteneur."
  type        = map(string)
  default     = {}
}

variable "container_secrets" {
  description = <<-EOT
    Map NOM_VAR_ENV => ARN de secret Secrets Manager. Chaque entrée est injectée
    dans le conteneur via le mécanisme `secrets` d'ECS (jamais en clair dans la
    task definition). Le rôle d'exécution reçoit le droit de lire ces ARNs.
  EOT
  type        = map(string)
  default     = {}
}

variable "secret_read_arns" {
  description = <<-EOT
    ARNs de BASE des secrets que le rôle d'exécution doit pouvoir lire (sans le
    suffixe ":clé-json::" éventuellement utilisé dans container_secrets). Permet
    d'autoriser la lecture du secret RDS géré par AWS injecté par clé.
  EOT
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "ARN de la clé KMS chiffrant les secrets/logs (pour autoriser kms:Decrypt). Optionnel."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR de la VPC (pour autoriser la sortie des tâches vers la base RDS)."
  type        = string
}

variable "db_port" {
  description = "Port de la base de données joignable par les tâches."
  type        = number
  default     = 5432
}

variable "health_check_path" {
  description = "Chemin HTTP de la sonde de l'ALB."
  type        = string
  default     = "/healthz"
}

variable "allowed_ingress_cidrs" {
  description = "CIDR autorisés à joindre l'ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = <<-EOT
    ARN d'un certificat ACM. Si fourni, l'ALB écoute en HTTPS (443) et redirige
    le port 80 vers 443. Si null, écoute HTTP (80) uniquement — acceptable pour
    une démo sans nom de domaine.
  EOT
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Rétention des logs applicatifs CloudWatch (jours)."
  type        = number
  default     = 30
}
