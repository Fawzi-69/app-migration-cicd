# ---------------------------------------------------------------------------
# Bootstrap : crée l'infrastructure socle nécessaire AVANT tout autre déploiement
#   - bucket S3 chiffré (KMS) et versionné : stockage des states Terraform
#   - table DynamoDB : verrou de state (lock) pour éviter les applies concurrents
#   - fournisseur OIDC GitLab : permet à la CI d'assumer un rôle sans clé statique
# Cette racine s'applique une seule fois, avec un state local.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# --- Clé KMS dédiée au chiffrement des states -------------------------------
resource "aws_kms_key" "tfstate" {
  description             = "Chiffrement des states Terraform (${var.project})"
  deletion_window_in_days = 7
  enable_key_rotation     = true # rotation annuelle automatique
  policy                  = data.aws_iam_policy_document.kms_tfstate.json
}

# Politique de clé explicite : le compte (via IAM) administre la clé.
# NB : une "key policy" est rattachée à la clé ; "*" en ressource y désigne la
# clé elle-même (et non toutes les ressources). Donner l'admin au compte root est
# la baseline recommandée par AWS — d'où les exemptions inline ci-dessous, qui
# ne désactivent ces règles QUE pour cette policy de clé (elles restent actives
# partout ailleurs).
data "aws_iam_policy_document" "kms_tfstate" {
  #checkov:skip=CKV_AWS_109:Key policy KMS — l'admin compte (root) est la baseline AWS recommandée
  #checkov:skip=CKV_AWS_111:Key policy (resource-based), pas une policy d'identité
  #checkov:skip=CKV_AWS_356:"*" = la clé portant cette policy (imposé pour une key policy)
  statement {
    sid       = "EnableAccountIAMPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"] # une key policy porte sur la clé elle-même (ressource imposée)
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/${var.project}-tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

# --- Bucket S3 des states ---------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name
}

# Versioning : conserve l'historique des states (rollback possible).
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement au repos via la clé KMS dédiée.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
    bucket_key_enabled = true
  }
}

# Cycle de vie : purge des anciennes versions et des uploads incomplets.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-noncurrent-and-incomplete"
    status = "Enabled"

    filter {} # s'applique à tout le bucket

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Blocage total des accès publics.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Refuse tout accès non chiffré en transit (TLS obligatoire).
resource "aws_s3_bucket_policy" "tfstate_tls_only" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_tls_only.json
}

data "aws_iam_policy_document" "tfstate_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# --- Table DynamoDB de verrouillage ----------------------------------------
resource "aws_dynamodb_table" "tf_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST" # pas de capacité à provisionner pour un usage CI
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Sauvegarde continue : récupération à un instant T en cas d'incident.
  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tfstate.arn
  }
}

# --- Fournisseur OIDC GitLab ------------------------------------------------
# Permet à la CI GitLab d'échanger son jeton OIDC contre des identifiants AWS
# temporaires (sts:AssumeRoleWithWebIdentity). Aucune clé d'accès statique.
resource "aws_iam_openid_connect_provider" "gitlab" {
  url             = var.gitlab_url
  client_id_list  = [var.gitlab_oidc_aud]
  thumbprint_list = var.gitlab_oidc_thumbprints
}
