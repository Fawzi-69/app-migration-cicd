# ---------------------------------------------------------------------------
# Module RDS : instance PostgreSQL privée, chiffrée, non exposée à Internet.
# Le mot de passe maître est généré et stocké par AWS dans Secrets Manager
# (manage_master_user_password) : aucun secret dans le code ni dans le state.
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids
}

# --- Rôle du monitoring renforcé (Enhanced Monitoring) ----------------------
resource "aws_iam_role" "monitoring" {
  name               = "${var.identifier}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# --- Security group de la base ---------------------------------------------
resource "aws_security_group" "this" {
  name        = "${var.identifier}-rds"
  description = "Accès PostgreSQL réservé aux SG applicatifs autorisés."
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.identifier}-rds" }
}

# Entrée : uniquement depuis les SG fournis (tâches ECS), sur le port DB.
resource "aws_vpc_security_group_ingress_rule" "from_app" {
  count                        = length(var.ingress_security_group_ids)
  security_group_id            = aws_security_group.this.id
  description                  = "PostgreSQL depuis le SG applicatif"
  referenced_security_group_id = var.ingress_security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = var.port
  to_port                      = var.port
}

# --- Instance ---------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = var.db_name
  username = var.master_username
  # Mot de passe généré et géré par AWS dans Secrets Manager (pas de password ici).
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn
  port                          = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  # Authentification IAM en complément du mot de passe.
  iam_database_authentication_enabled = true

  # Sauvegardes, supervision, maintenance.
  backup_retention_period      = var.backup_retention_days
  copy_tags_to_snapshot        = true
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  # Performance Insights chiffré avec la même clé KMS (ou clé AWS si null).
  performance_insights_kms_key_id = var.kms_key_arn
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Monitoring renforcé : métriques OS fines via un rôle dédié.
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.monitoring.arn : null

  deletion_protection = var.deletion_protection
  # En démo on n'exige pas de snapshot final ; à activer en prod réelle.
  skip_final_snapshot = true
}
