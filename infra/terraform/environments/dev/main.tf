# ---------------------------------------------------------------------------
# Composition de l'environnement : assemble les modules réutilisables.
# State isolé par environnement (clé backend distincte). Identique entre dev et
# prod ; seules les valeurs (terraform.tfvars) et la clé de state changent.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Dépôt ECR partagé, créé par le bootstrap (jamais recréé par l'environnement).
data "aws_ecr_repository" "app" {
  name = var.project
}

locals {
  name       = "${var.project}-${var.env}"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # ARNs reconstruits à partir des noms : aucun identifiant de compte en dur.
  oidc_provider_arn    = "arn:aws:iam::${local.account_id}:oidc-provider/${var.oidc_provider_host}"
  state_bucket_arn     = "arn:aws:s3:::${var.state_bucket_name}"
  state_lock_table_arn = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.lock_table_name}"

  image = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
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

# --- Secrets applicatifs (placeholders, valeurs injectées hors Terraform) ---
module "secrets" {
  source = "../../modules/secrets"

  name_prefix = local.name
  # Les identifiants de base proviennent du secret RDS géré par AWS (cf. module
  # rds) ; ici on ne déclare que les secrets purement applicatifs.
  secrets = {
    app_secret = "Secret applicatif générique"
  }
}

# --- Base de données --------------------------------------------------------
# Créée avant le service : ce dernier consomme l'endpoint et le secret RDS.
module "rds" {
  source = "../../modules/rds"

  identifier = local.name
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  instance_class      = var.rds_instance_class
  multi_az            = var.rds_multi_az
  deletion_protection = var.rds_deletion_protection
  skip_final_snapshot = var.rds_skip_final_snapshot
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
  db_port            = module.rds.port

  image          = local.image
  container_port = var.container_port
  cpu            = var.cpu
  memory         = var.memory
  desired_count  = var.desired_count
  min_capacity   = var.min_capacity
  max_capacity   = var.max_capacity

  # Coordonnées de base non sensibles, injectées en variables d'environnement.
  environment = {
    APP_ENV     = var.env
    APP_VERSION = var.image_tag
    DB_HOST     = module.rds.address
    DB_PORT     = tostring(module.rds.port)
    DB_NAME     = module.rds.db_name
  }

  # Identifiants sensibles injectés par clé depuis le secret RDS géré par AWS
  # (+ secret applicatif). Jamais en clair dans la task definition.
  container_secrets = {
    DB_USERNAME = "${module.rds.master_user_secret_arn}:username::"
    DB_PASSWORD = "${module.rds.master_user_secret_arn}:password::"
    APP_SECRET  = module.secrets.secret_arns["app_secret"]
  }

  # ARNs de base autorisés en lecture pour le rôle d'exécution.
  secret_read_arns = concat(
    values(module.secrets.secret_arns),
    [module.rds.master_user_secret_arn],
  )

  certificate_arn = var.certificate_arn
}

# Flux réseau tâches -> base, posé ici pour découpler les modules rds/ecs_service.
resource "aws_vpc_security_group_ingress_rule" "rds_from_tasks" {
  security_group_id            = module.rds.security_group_id
  description                  = "PostgreSQL depuis les tâches Fargate"
  referenced_security_group_id = module.ecs_service.task_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = module.rds.port
  to_port                      = module.rds.port
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

  ecr_repository_arn = data.aws_ecr_repository.app.arn
  passrole_arns = [
    module.ecs_service.execution_role_arn,
    module.ecs_service.task_role_arn,
  ]

  state_bucket_arn     = local.state_bucket_arn
  state_lock_table_arn = local.state_lock_table_arn
  state_kms_key_arn    = var.state_kms_key_arn

  # Permissions de provisioning : bornées à la région de l'env + rôles préfixés.
  enable_terraform_provisioning = true
  provisioning_region           = var.aws_region
  project_prefix                = var.project

  additional_policy_arns = var.additional_ci_policy_arns
}
