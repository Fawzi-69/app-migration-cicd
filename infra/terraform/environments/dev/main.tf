# ---------------------------------------------------------------------------
# Composition de l'environnement : assemble les modules réutilisables.
# State isolé par environnement (clé backend distincte). Identique entre dev et
# prod ; seules les valeurs (terraform.tfvars) et la clé de state changent.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name       = "${var.project}-${var.env}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # ARNs reconstruits à partir des noms : aucun identifiant de compte en dur.
  oidc_provider_arn    = "arn:aws:iam::${local.account_id}:oidc-provider/${var.oidc_provider_host}"
  state_bucket_arn     = "arn:aws:s3:::${var.state_bucket_name}"
  state_lock_table_arn = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.lock_table_name}"

  image = "${module.ecr.repository_url}:${var.image_tag}"
}

# --- Réseau -----------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  cidr               = var.vpc_cidr
  azs                = var.azs
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  single_nat_gateway = var.single_nat_gateway
}

# --- Registre d'images ------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  name = var.project
}

# --- Secrets applicatifs (placeholders, valeurs injectées hors Terraform) ---
module "secrets" {
  source = "../../modules/secrets"

  name_prefix = local.name
  secrets = {
    database_url = "URL de connexion PostgreSQL de l'application"
    app_secret   = "Secret applicatif générique"
  }
}

# --- Service applicatif (ECS Fargate + ALB) ---------------------------------
module "ecs_service" {
  source = "../../modules/ecs_service"

  name               = local.name
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  image          = local.image
  container_port = var.container_port
  cpu            = var.cpu
  memory         = var.memory
  desired_count  = var.desired_count
  min_capacity   = var.min_capacity
  max_capacity   = var.max_capacity

  environment = {
    APP_ENV     = var.env
    APP_VERSION = var.image_tag
  }

  # Le secret database_url est injecté dans la variable DATABASE_URL attendue
  # par l'application (mécanisme `secrets` d'ECS, jamais en clair).
  container_secrets = {
    DATABASE_URL = module.secrets.secret_arns["database_url"]
    APP_SECRET   = module.secrets.secret_arns["app_secret"]
  }

  certificate_arn = var.certificate_arn
}

# --- Base de données --------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  identifier = local.name
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  # Seules les tâches ECS peuvent joindre la base.
  ingress_security_group_ids = [module.ecs_service.task_security_group_id]

  instance_class      = var.rds_instance_class
  multi_az            = var.rds_multi_az
  deletion_protection = var.rds_deletion_protection
}

# --- Rôle CI assumé via OIDC ------------------------------------------------
module "ci_role" {
  source = "../../modules/iam_oidc_role"

  name               = "${local.name}-ci"
  oidc_provider_arn  = local.oidc_provider_arn
  oidc_provider_host = var.oidc_provider_host
  oidc_aud           = var.oidc_aud

  subject_claims = [
    "project_path:${var.gitlab_project_path}:ref_type:branch:ref:${var.gitlab_branch}",
  ]

  ecr_repository_arn = module.ecr.repository_arn
  passrole_arns = [
    module.ecs_service.execution_role_arn,
    module.ecs_service.task_role_arn,
  ]

  state_bucket_arn     = local.state_bucket_arn
  state_lock_table_arn = local.state_lock_table_arn
  state_kms_key_arn    = var.state_kms_key_arn

  additional_policy_arns = var.additional_ci_policy_arns
}
