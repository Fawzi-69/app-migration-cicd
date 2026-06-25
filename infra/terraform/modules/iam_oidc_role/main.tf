# ---------------------------------------------------------------------------
# Rôle assumé par la CI GitLab via OIDC (sts:AssumeRoleWithWebIdentity).
# Aucune clé d'accès statique : le jeton OIDC court-vivant est échangé contre
# des identifiants temporaires, sous conditions strictes (audience + sujet).
# ---------------------------------------------------------------------------

# --- Politique de confiance (qui peut assumer le rôle) ----------------------
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # L'audience doit correspondre exactement.
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_host}:aud"
      values   = [var.oidc_aud]
    }

    # Le sujet (projet + référence) doit figurer dans la liste autorisée.
    condition {
      test     = "StringLike"
      variable = "${var.oidc_provider_host}:sub"
      values   = var.subject_claims
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

# --- Politique de livraison (périmètre explicite et restreint) --------------
data "aws_iam_policy_document" "deploy" {
  # Authentification au registre ECR. GetAuthorizationToken n'accepte pas de
  # ressource précise : le "*" est imposé par l'API AWS (jeton de session).
  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push/pull limités au dépôt de l'application.
  statement {
    sid    = "EcrPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }

  # Déploiement applicatif : enregistrement de task definition + mise à jour
  # du service. RegisterTaskDefinition n'accepte pas de ressource (imposé AWS).
  statement {
    sid       = "EcsRegisterTaskDef"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid    = "EcsDeploy"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = ["*"]
    # Restreint aux services du projet via une condition sur le cluster.
    condition {
      test     = "ArnLike"
      variable = "ecs:cluster"
      values   = ["arn:aws:ecs:*:*:cluster/${replace(var.name, "-ci", "")}*"]
    }
  }

  # Transmission des rôles d'exécution/tâche à ECS, restreinte à ces ARNs.
  statement {
    sid       = "PassEcsRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = var.passrole_arns
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Backend Terraform : state S3 + verrou DynamoDB.
  statement {
    sid       = "TerraformStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
  }

  statement {
    sid       = "TerraformStateObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/*"]
  }

  statement {
    sid    = "TerraformLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [var.state_lock_table_arn]
  }

  # Déchiffrement/chiffrement du state (clé KMS), si fournie.
  dynamic "statement" {
    for_each = var.state_kms_key_arn == null ? [] : [var.state_kms_key_arn]
    content {
      sid       = "TerraformStateKms"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.name}-deploy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.deploy.json
}

# Politiques gérées additionnelles (ex. permissions d'apply infra), si fournies.
resource "aws_iam_role_policy_attachment" "additional" {
  count      = length(var.additional_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = var.additional_policy_arns[count.index]
}
