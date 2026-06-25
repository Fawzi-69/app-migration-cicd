variable "aws_region" {
  description = "Région AWS où créer le backend de state et le provider OIDC."
  type        = string
  default     = "eu-west-3" # Paris
}

variable "project" {
  description = "Nom du projet, utilisé pour le tag Project et le préfixe des ressources."
  type        = string
  default     = "app-migration-cicd"
}

variable "owner" {
  description = "Propriétaire/équipe responsable (tag Owner)."
  type        = string
  default     = "fawzi"
}

variable "state_bucket_name" {
  description = "Nom GLOBALEMENT unique du bucket S3 hébergeant les states Terraform."
  type        = string
}

variable "lock_table_name" {
  description = "Nom de la table DynamoDB de verrouillage des states."
  type        = string
  default     = "app-migration-cicd-tf-locks"
}

variable "gitlab_url" {
  description = "URL de l'instance GitLab émettrice des jetons OIDC."
  type        = string
  default     = "https://gitlab.com"
}

variable "gitlab_oidc_aud" {
  description = "Audience (aud) attendue dans les jetons OIDC GitLab."
  type        = string
  default     = "https://gitlab.com"
}

variable "gitlab_oidc_thumbprints" {
  description = <<-EOT
    Empreintes (SHA1) des certificats racine du fournisseur OIDC GitLab.
    Pour gitlab.com, AWS valide désormais la chaîne TLS publiquement ; on
    fournit l'empreinte connue pour rester compatible avec l'API du provider.
  EOT
  type        = list(string)
  # Empreinte de la CA publique de gitlab.com (à revérifier lors d'une rotation).
  default = ["b3dd7606d2b5a8b4a13771dbecc9ee1cecafa38a"]
}
