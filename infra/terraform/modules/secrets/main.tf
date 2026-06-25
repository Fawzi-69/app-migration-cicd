# ---------------------------------------------------------------------------
# Module secrets : crée des secrets Secrets Manager (chiffrés) avec une valeur
# PLACEHOLDER. La valeur réelle est renseignée hors Terraform : ni le code ni le
# state ne contiennent de donnée sensible.
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name                    = "${var.name_prefix}/${each.key}"
  description             = each.value
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_days
}

# Version initiale = placeholder. On ignore les modifications ultérieures de la
# valeur (renseignée manuellement / par un processus dédié), ce qui évite que
# Terraform n'écrase ou ne lise le secret réel.
resource "aws_secretsmanager_secret_version" "placeholder" {
  for_each = aws_secretsmanager_secret.this

  secret_id = each.value.id
  # Chaîne simple injectée telle quelle dans le conteneur (ex. une URL de
  # connexion complète). Remplacée hors Terraform par la valeur réelle.
  secret_string = "REPLACE_ME"

  lifecycle {
    ignore_changes = [secret_string]
  }
}
