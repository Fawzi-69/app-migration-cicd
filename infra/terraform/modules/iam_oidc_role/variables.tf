variable "name" {
  description = "Nom du rôle (ex. app-migration-cicd-dev-ci)."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN du fournisseur OIDC GitLab (sortie du bootstrap)."
  type        = string
}

variable "oidc_provider_host" {
  description = "Hôte du fournisseur OIDC sans schéma (ex. gitlab.com), pour les clés de condition."
  type        = string
  default     = "gitlab.com"
}

variable "oidc_aud" {
  description = "Audience attendue dans le jeton OIDC."
  type        = string
  default     = "https://gitlab.com"
}

variable "subject_claims" {
  description = <<-EOT
    Liste des `sub` GitLab autorisés à assumer le rôle. Restreint le rôle à un
    projet et à une (des) référence(s) précises. Exemple :
    ["project_path:mon-groupe/app-migration-cicd:ref_type:branch:ref:main"].
  EOT
  type        = list(string)
}

variable "ecr_repository_arn" {
  description = "ARN du dépôt ECR sur lequel autoriser le push d'images."
  type        = string
}

variable "passrole_arns" {
  description = "ARNs des rôles que la CI peut transmettre à ECS (execution + task roles)."
  type        = list(string)
}

variable "state_bucket_arn" {
  description = "ARN du bucket S3 des states (accès lecture/écriture pour Terraform)."
  type        = string
}

variable "state_lock_table_arn" {
  description = "ARN de la table DynamoDB de verrou."
  type        = string
}

variable "state_kms_key_arn" {
  description = "ARN de la clé KMS chiffrant le state (déchiffrement par la CI). Optionnel."
  type        = string
  default     = null
}

variable "additional_policy_arns" {
  description = <<-EOT
    Politiques gérées supplémentaires à attacher (ex. permissions Terraform pour
    gérer VPC/ECS/RDS lors d'un `apply`). Vide par défaut : on attache un
    périmètre explicite et restreint plutôt qu'un accès large.
  EOT
  type        = list(string)
  default     = []
}
