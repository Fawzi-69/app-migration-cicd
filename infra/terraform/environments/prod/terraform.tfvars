# Valeurs de l'environnement PROD : haute disponibilité et garde-fous renforcés.

env = "prod"

# Réseau distinct de dev (plages non chevauchantes).
vpc_cidr        = "10.20.0.0/16"
azs             = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
public_subnets  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
private_subnets = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]

# Prod : NAT par AZ, plus de capacité, multi-AZ, suppression protégée.
single_nat_gateway      = false
desired_count           = 3
min_capacity            = 3
max_capacity            = 12
cpu                     = 512
memory                  = 1024
rds_instance_class      = "db.t4g.small"
rds_multi_az            = true
rds_deletion_protection = true
rds_skip_final_snapshot = false # prod : snapshot final obligatoire

# CI/CD : déploiement prod déclenché depuis la branche principale.
gitlab_project_path = "fawzi/app-migration-cicd"
gitlab_branch       = "main"

# Backend (créés par le bootstrap) — remplacer <suffixe-unique>.
state_bucket_name = "app-migration-cicd-tfstate-<suffixe-unique>"
lock_table_name   = "app-migration-cicd-tf-locks"
# state_kms_key_arn = "arn:aws:kms:eu-west-3:<account-id>:key/<id>"  # sortie du bootstrap
