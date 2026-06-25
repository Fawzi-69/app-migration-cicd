# ---------------------------------------------------------------------------
# Rôles IAM des tâches ECS :
#   - execution role : utilisé par l'agent ECS pour tirer l'image (ECR),
#     écrire les logs et lire les secrets injectés. Permissions minimales.
#   - task role      : identité du conteneur lui-même. Vide par défaut
#     (l'app de démo n'appelle aucune API AWS) — least-privilege strict.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- Execution role ---------------------------------------------------------
resource "aws_iam_role" "execution" {
  name               = "${var.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

# Politique gérée AWS : pull ECR + écriture des logs CloudWatch (strictement
# le périmètre d'exécution standard d'une tâche).
resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Lecture des secrets injectés + déchiffrement KMS associé, limités aux ARNs
# réellement utilisés (aucun wildcard de ressource).
data "aws_iam_policy_document" "execution_secrets" {
  count = length(var.container_secrets) > 0 ? 1 : 0

  statement {
    sid       = "ReadInjectedSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = distinct(values(var.container_secrets))
  }

  dynamic "statement" {
    for_each = var.kms_key_arn == null ? [] : [var.kms_key_arn]
    content {
      sid       = "DecryptSecretsKey"
      effect    = "Allow"
      actions   = ["kms:Decrypt"]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  count  = length(var.container_secrets) > 0 ? 1 : 0
  name   = "${var.name}-read-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets[0].json
}

# --- Task role (identité applicative) --------------------------------------
resource "aws_iam_role" "task" {
  name               = "${var.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
  # Aucune politique attachée : l'application de démo n'accède à aucune API AWS.
  # On scopera ici les droits réels (S3, SQS, ...) le jour où l'app en a besoin.
}
