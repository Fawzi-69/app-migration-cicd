variable "name" {
  description = "Nom du dépôt ECR (ex. app-migration-cicd)."
  type        = string
}

variable "image_tag_mutability" {
  description = "IMMUTABLE empêche d'écraser un tag déjà poussé (traçabilité)."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability doit valoir IMMUTABLE ou MUTABLE."
  }
}

variable "scan_on_push" {
  description = "Active le scan de vulnérabilités à chaque push d'image."
  type        = bool
  default     = true
}

variable "keep_last_n_images" {
  description = "Nombre d'images récentes à conserver (les plus anciennes sont purgées)."
  type        = number
  default     = 10
}

variable "kms_key_arn" {
  description = "ARN d'une clé KMS pour chiffrer le dépôt. Si null, chiffrement AES256 géré par AWS."
  type        = string
  default     = null
}
