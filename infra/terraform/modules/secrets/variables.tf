variable "name_prefix" {
  description = "Préfixe des noms de secrets (ex. app-migration-cicd/dev)."
  type        = string
}

variable "secrets" {
  description = <<-EOT
    Map nom_logique => description. Pour chaque entrée, un secret Secrets Manager
    est créé avec une valeur PLACEHOLDER. La valeur réelle est injectée hors
    Terraform (console/CLI/pipeline) : aucune donnée sensible dans le code ni le state.
  EOT
  type        = map(string)
}

variable "kms_key_arn" {
  description = "ARN de la clé KMS chiffrant les secrets. Si null, clé gérée par AWS (aws/secretsmanager)."
  type        = string
  default     = null
}

variable "recovery_window_days" {
  description = "Délai de récupération après suppression d'un secret (0 = suppression immédiate)."
  type        = number
  default     = 7
}
