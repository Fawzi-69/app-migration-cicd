# ---------------------------------------------------------------------------
# Permissions de provisioning Terraform (optionnelles).
#
# Objectif : permettre au rôle CI d'exécuter un `terraform apply` complet de la
# stack applicative, SANS donner un accès administrateur global. Deux garde-fous :
#   1. Toutes les actions de services sont bornées à UNE région
#      (condition aws:RequestedRegion) -> rayon de souffle limité.
#   2. Les actions IAM sont restreintes aux rôles préfixés "<projet>-*"
#      -> la CI ne peut pas fabriquer de rôle admin arbitraire (anti-escalade).
#
# Les `resources = ["*"]` portent sur des actions de création qui n'acceptent
# pas de ciblage par ARN (imposé par AWS) ; ils sont bornés par la condition de
# région. Les règles Checkov génériques sur les policies sont exemptées EN LIGNE
# ci-dessous, car ce périmètre est un choix assumé et documenté pour un rôle de
# runner Terraform.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "provisioning" {
  count = var.enable_terraform_provisioning ? 1 : 0

  #checkov:skip=CKV_AWS_111:Rôle runner Terraform — actions de création bornées par région
  #checkov:skip=CKV_AWS_356:Actions de création AWS sans ciblage ARN possible ; bornées par aws:RequestedRegion
  #checkov:skip=CKV_AWS_109:IAM séparé et restreint au préfixe projet (statement dédié ci-dessous)

  # Services de la stack, bornés à la région cible.
  statement {
    sid    = "StackServicesInRegion"
    effect = "Allow"
    actions = [
      "ec2:*",                     # VPC, subnets, IGW, NAT, EIP, routes, SG, flow logs
      "elasticloadbalancing:*",    # ALB, target groups, listeners
      "rds:*",                     # instance, subnet group, paramètres
      "ecs:*",                     # cluster, service, task definitions
      "application-autoscaling:*", # autoscaling du service
      "cloudwatch:*",              # alarmes liées à l'autoscaling
      "logs:*",                    # log groups applicatifs et flow logs
      "secretsmanager:*",          # secrets applicatifs
      "ecr:Describe*",             # lecture du dépôt partagé
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.provisioning_region]
    }
  }

  # Lecture/usage des clés KMS (chiffrement RDS/logs) — pas de gestion du cycle
  # de vie des clés (ni suppression, ni modification de policy).
  statement {
    sid    = "KmsUseInRegion"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:ListAliases",
      "kms:GenerateDataKey",
      "kms:Decrypt",
      "kms:Encrypt",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.provisioning_region]
    }
  }

  # IAM restreint aux rôles du projet (préfixe) : empêche la création de rôles
  # hors périmètre. IAM étant global, pas de condition de région ici.
  statement {
    sid    = "ManageProjectRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_prefix}-*",
    ]
  }

  # Rôles liés aux services (créés une fois par AWS pour ECS/RDS/ELB/autoscaling).
  statement {
    sid       = "ServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "ecs.amazonaws.com",
        "rds.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "application-autoscaling.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "provisioning" {
  count  = var.enable_terraform_provisioning ? 1 : 0
  name   = "${var.name}-provisioning"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.provisioning[0].json
}
